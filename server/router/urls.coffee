crypto = require('crypto')
Authorize = require('../room/authorize')


module.exports.authorize = (config, app)->
  links =
    facebook: ->
      'https://www.facebook.com/v2.12/dialog/oauth?' +
        'client_id=' + config.facebook.id +
        '&scope=&response_type=token' +
        '&redirect_uri=' + config.server + '/g'
    draugiem: ->
      'https://api.draugiem.lv/authorize/?app=' + config.draugiem.id +
          '&hash=' + crypto.createHash('md5').update(config.draugiem.key + config.server + '/g').digest('hex') +
          '&redirect=' + config.server + '/g'
    google: ->
      'https://accounts.google.com/o/oauth2/v2/auth?scope=profile&response_type=code&redirect_uri=' +
        config.server + '/g' + '&client_id=' + config.google.id
  Object.keys(links).forEach (platform)->
    if config[platform]
      app.get config[platform].login_full, (req, res)-> res.redirect links[platform]()


module.exports.payments = (config, app, callback)->
  transaction =
    callback: (id, platform, callback)=>
      new (Authorize[platform])().buy_complete id, (params)=>
        callback Object.assign {platform}, params
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
    if !config[platform]
      return
    if config[platform].transaction
      transaction.platforms[platform](platform, config[platform].transaction)
