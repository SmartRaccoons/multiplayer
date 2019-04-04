crypto = require('crypto')
Authorize = require('../authorize')
SocketIO = require('socket.io')
module_get = require('../../config').module_get
config_get = require('../../config').config_get
config_callback = require('../../config').config_callback
template_local = require('../helpers/template').generate_local


Anonymous = null
locale = null
template = null
User = null
config_callback( ->
  Anonymous = module_get('server.authorize').Anonymous
  locale = module_get('locale')
  template = module_get('server.helpers.template')
  User = module_get('server.user').User
)()


module.exports.authorize = (app)->
  code_url = config_get('code_url')
  code_template = do =>
    a_code_id = template_local('a-code-id')
    (params)=> a_code_id Object.assign({message: '', error: ''}, params)
  code_parse = (code)-> [ locale.lang_long(code.substr(0, 1)), code.substr(1) ]

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
        [language, code] = code_parse(req.params.id)
        config_get('dbmemory').random_get 'anonymous', code, (params)=>
          if !params
            return res.send code_template({
              error: locale._('Link error', language)
              message: locale._('Link error desc', language)
            })
          res.redirect links[platform](code_url, req.params.id)
  do =>
    a_code = template_local('a-code')()
    app.get code_url, (req, res)-> res.send a_code
    platforms =
      draugiem: 'dr_auth_code'
      facebook: 'access_token'
      google: 'code'
    app.get "#{code_url}/:id", (req, res)->
      [language, code] = code_parse(req.params.id)
      config_get('dbmemory').random_get 'anonymous', code, (params)=>
        if !params
          return res.send code_template({
            error: locale._('Link error', language)
            message: locale._('Link error device', language)
          })
        for platform, param_url of platforms
          if req.query[param_url]
            params.authenticate = { [platform]: decodeURIComponent(req.query[param_url]), params: {code_url: true}}
            config_get('dbmemory').random_up 'anonymous', code, params
            Anonymous::emit_self_exec.apply Anonymous::, [params.id, 'authenticate', params.authenticate ]
            res.send code_template({message: locale._('A code ok', language)})
            return
        return res.send code_template({error: locale._('Error', language)})


module.exports.index = (app, locales)->
  index = locales.reduce (acc, language)->
    acc[language] = template.generate({
      template: 'index'
      _l: (v)-> locale._(v, language)
    })
    acc
  , {}
  app.get '/', (req, res)->
    language = if req.query and locales.indexOf(req.query.lang) >= 0 then req.query.lang else locales[0]
    res.send index[language]


module.exports.payments = (app)->
  transaction =
    callback: (id, platform, callback)=>
      new (Authorize[platform])().buy_complete id, (params)=>
        User::_coins_buy_callback[params.service](Object.assign {platform}, params)
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
      serveClient: false
      # pingInterval: 7 * 1000
      # pingTimeout: 30 * 1000
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
