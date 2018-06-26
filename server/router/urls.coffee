crypto = require('crypto')
Authorize = require('../room/authorize')
SocketIO = require('socket.io')
config_get = require('../../config').config_get

module.exports.authorize = (app)->
  links =
    facebook: ->
      'https://www.facebook.com/v2.12/dialog/oauth?' +
        'client_id=' + config_get('facebook').id +
        '&scope=&response_type=token' +
        '&redirect_uri=' + config_get('server') + '/g'
    draugiem: ->
      'https://api.draugiem.lv/authorize/?app=' + config_get('draugiem').id +
          '&hash=' + crypto.createHash('md5').update(config_get('draugiem').key + config_get('server') + '/g').digest('hex') +
          '&redirect=' + config_get('server') + '/g'
    google: ->
      'https://accounts.google.com/o/oauth2/v2/auth?scope=profile&response_type=code&redirect_uri=' +
        config_get('server') + '/g' + '&client_id=' + config_get('google').id
  Object.keys(links).forEach (platform)->
    if config_get(platform)
      app.get config_get(platform).login_full, (req, res)-> res.redirect links[platform]()


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


module.exports.socket = (server, log, version, callback)->
  Socket = require('../helpers/socket')(log, 1000 * 60 * 20, version)
  SocketIO(server, {
    pingTimeout: 10 * 1000
    pingInterval: 5 * 1000
  }).on 'connection', (client)->
    socket = new Socket(client.handshake.query, client.id)
    socket._send = (data)-> client.emit('request', data)
    if not socket.version_check()
      client.emit 'version', {'actual': pjson.version}
      return
    client.emit 'session', socket.id
    socket.client = client
    client.socket = socket
    log([socket.client.id, 'connection', socket.id, client.request.connection.remoteAddress].join(' : '))
    client.on 'request', (data)->
      if !(data and Array.isArray(data) and data[0])
        return console.info socket.client.id + ': request error: ' + JSON.stringify(data) + ' : ' + socket.id
      log(socket.client.id + ': data: ' + JSON.stringify(data) + ' : ' + socket.id)
      socket.emit('alive')
      socket.emit.apply(socket, data)
    client.on 'request_receive', -> socket.received()
    disconnect = (reason)->
      log("gone offline: #{reason}; #{socket.immediate()}" )
      socket.remove()
      client._disconnected = true
    client.on 'disconnect', (reason)-> disconnect(reason)
    socket.disconnect = (reason, immediate = true)->
      if reason is 'duplicate'
        client.emit('error:duplicate')
      socket._immediate = immediate
      if not client._disconnected
        return client.disconnect(true)
      disconnect(reason)
    socket.check()
    callback(socket)
