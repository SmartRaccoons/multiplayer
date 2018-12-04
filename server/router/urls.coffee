crypto = require('crypto')
Authorize = require('../room/authorize')
SocketIO = require('socket.io')
module_get = require('../../config').module_get
config_get = require('../../config').config_get
config_callback = require('../../config').config_callback
template_local = require('../helpers/template').generate_local


Anonymous = null
locale = null
config_callback( ->
  Anonymous = module_get('server.room.anonymous').Anonymous
  locale = module_get('locale')
)()


module.exports.authorize = (app)->
  links =
    facebook: (path = '/g', code = '')->
      'https://www.facebook.com/v2.12/dialog/oauth?' +
        'client_id=' + config_get('facebook').id +
        '&scope=&response_type=token' +
        '&redirect_uri=' + config_get('server') + path +
        '&state=' + code
    draugiem: (path = '/g', code = '')->
      if code
        path = "#{path}/#{code}"
      'https://api.draugiem.lv/authorize/?app=' + config_get('draugiem').id +
          '&hash=' + crypto.createHash('md5').update(config_get('draugiem').key + config_get('server') + path).digest('hex') +
          '&redirect=' + config_get('server') + path
    google: (path = '/g', code = '')->
      'https://accounts.google.com/o/oauth2/v2/auth?scope=profile&response_type=code&redirect_uri=' +
        config_get('server') + path + '&client_id=' + config_get('google').id +
        '&state=' + code
  Object.keys(links).forEach (platform)->
    if config_get(platform)
      app.get config_get(platform).login_full, (req, res)-> res.redirect links[platform]()
      app.get config_get(platform).login + '/:id', (req, res)->
        res.redirect links[platform]("/a-code", req.params.id)
  do =>
    a_code = template_local('a-code')()
    app.get '/a-code', (req, res)-> res.send a_code
    a_code_id = template_local('a-code-id')
    app.get '/a-code/:id', (req, res)->
      config_get('dbmemory').random_get 'anonymous', req.params.id, (params)=>
        if !params
          return res.send a_code_id({message: 'ERROR'})
        Anonymous::emit_self_exec.apply Anonymous::, [params.id, 'authenticate', req.query]
        res.send a_code_id({message: locale._('A code ok', params.language)})


module.exports.payments = (app, callback_router)->
  transaction =
    callback: (id, platform, callback)=>
      new (Authorize[platform])().buy_complete id, (params)=>
        callback_router Object.assign {platform}, params
      , callback
    platforms:
      draugiem: (platform, url)->
        app.get url, (req, res)->
          transaction.callback req.query.id, platform, (err)->
            if err
              console.info 'transaction draugiem', err, req.query.id
            res.send('OK')
      facebook: (platform, url)->
        app.all url, (req, res)->
          if req.method is 'GET'
            return res.send(req.query['hub.challenge'])
          if not (req.body and req.body.object is 'payments')
            return res.sendStatus(404)
          if req.body.entry.length isnt 1
            console.info 'facebook payment', req.body.entry
            return res.sendStatus(404)
          transaction.callback req.body.entry[0].id, platform, (err)->
            if err
              console.info 'facebook payment', err, req.body
              return res.sendStatus(404)
            res.send('OK')
      inbox: (platform, url)->
        app.post url, (req, res)->
          if !req.query.transaction_uuid
            console.info 'transaction inbox request error', req.query
            return
          transaction.callback req.query.transaction_uuid, platform, (error)->
            if error
              console.info 'transaction inbox', error, req.query
              res.send('ERROR')
              return
            res.send('OK')
  Object.keys(transaction.platforms).forEach (platform)->
    if !config_get(platform)
      return
    if config_get(platform).transaction
      transaction.platforms[platform](platform, config_get(platform).transaction)


module.exports.socket = ({ server, log, version, callback })->
  Socket = require('../helpers/socket')({ version })
  SocketIO(server, {
    pingTimeout: 10 * 1000
    pingInterval: 5 * 1000
  }).on 'connection', (client)->
    socket = new Socket(client.handshake.query)
    socket.send = ->
      log("write:#{client.id}:#{JSON.stringify(Array.from(arguments))}")
      client.emit('request', Array.from(arguments))
    if not socket.version_check()
      client.emit 'version', {'actual': version}
      return
    client.on 'request', (data)->
      if !(data and Array.isArray(data) and data[0])
        return console.info client.id + ': request error: ' + JSON.stringify(data)
      log("receive:#{client.id}:#{JSON.stringify(data)}")
      socket.emit('alive')
      socket.emit.apply(socket, data)
    client.on 'disconnect', (reason)-> socket.remove()
    socket.disconnect = (reason)->
      if reason is 'duplicate'
        client.emit 'error:duplicate'
      client.disconnect(true)
    callback(socket)
