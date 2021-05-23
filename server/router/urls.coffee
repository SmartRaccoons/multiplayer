bodyParser = require('body-parser')
typeis = require('type-is')
crypto = require('crypto')
SocketIO = require('socket.io')
module_get = require('../../config').module_get
config_get = require('../../config').config_get
config_callback = require('../../config').config_callback
template_local = require('../helpers/template').generate_local


Anonymous = null
Authorize = null
AuthorizeEmail = null
locale = null
template = null
User = null
config_callback( ->
  Anonymous = module_get('server.authorize').Anonymous
  Authorize = module_get('server.authorize')
  AuthorizeEmail = module_get('server.authorize').email
  locale = module_get('locale')
  template = module_get('server.helpers.template')
  User = module_get('server.user').User
)()


module.exports.authorize = (app)->
  language_validate = (language)->
    if ['lv', 'en', 'ru', 'de', 'lg'].indexOf(language) >= 0 then language else 'en'
  code_url = config_get('code_url')
  code_template = do =>
    a_code_id = template_local('a-code-id')
    (params)=> a_code_id Object.assign({message: '', error: ''}, params)
  code_parse = (code)-> [ locale.lang_long(code.substr(0, 1)), code.substr(1) ]

  links =
    facebook: (path = '/g', code = '')->
      'https://www.facebook.com/v7.0/dialog/oauth?' +
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
    apple: (path = '/g', code = '', language = '')->
      "https://appleid.apple.com/auth/authorize?" +
      "response_type=code%20id_token" +
      "&client_id=" + config_get('apple').client_id +
      "&redirect_uri=" + encodeURIComponent(config_get('server') + config_get('apple').login_post) +
      "&scope=" + 'name' +
      "&response_mode=form_post" +
      "&state=" + code + ';' + path + ';' + language
  Object.keys(links).forEach (platform)->
    if !config_get(platform)
      return
    if platform is 'apple'
      app.post config_get(platform).login_post, (req, res)->
        params = (req.body.state or '').split(';')
        params_code = params[0]
        params_url = if params[1] is code_url then code_url else '/g'
        params_language = language_validate(if params[2] then params[2] else '')
        new (Authorize.apple)().authorize {code: req.body.code, language: params_language, params: {user: req.body.user, post: true} }, (user)=>
          res.redirect "#{params_url}?apple=#{req.body.code}&state=#{params_code}"
    if platform is 'facebook' and config_get(platform).deletion_callback
      app.post config_get(platform).deletion_callback, (req, res)->
        console.log(req.body)
        console.log(req.query)

    app.get config_get(platform).login_full, (req, res)->
      res.redirect links[platform]('/g', '', language_validate(req.query.language))
    app.get config_get(platform).login + '/:id', (req, res)->
      [language, code] = code_parse(req.params.id)
      config_get('dbmemory').random_get Anonymous::_module(), code, (params)=>
        if !params
          return res.send code_template({
            error: locale._('UserNotify.Link error', language)
            message: locale._('UserNotify.Link error desc', language)
          })
        res.redirect links[platform](code_url, req.params.id, language)
  do =>
    a_code = template_local('a-code')({code_url})
    app.get code_url, (req, res)-> res.send a_code
    platforms =
      draugiem: 'dr_auth_code'
      facebook: 'access_token'
      google: 'code'
      apple: 'apple'
    app.get "#{code_url}/:id", (req, res)->
      [language, code] = code_parse(req.params.id)
      config_get('dbmemory').random_get Anonymous::_module(), code, (params)=>
        if !params
          return res.send code_template({
            error: locale._('UserNotify.Link error', language)
            message: locale._('UserNotify.Link error device', language)
          })
        for platform, param_url of platforms
          if req.query[param_url]
            params.authenticate = { [platform]: decodeURIComponent(req.query[param_url]), params: {code_url: true}}
            config_get('dbmemory').random_up Anonymous::_module(), code, params
            Anonymous::emit_self_exec.apply Anonymous::, [params.id, 'authenticate', params.authenticate ]
            res.send code_template({message: locale._('UserNotify.A code ok', language)})
            return
        return res.send code_template({error: locale._('UserNotify.Error', language)})

  do =>
    email = config_get('email')
    if !email
      return
    template_email_recovery = do =>
      template_email = template_local('email.recovery')
      (params)=> template_email Object.assign({error: '', success: ''}, params)
    app.all email.forget + '/:id/:user_id', (req, res)->
      [language, code] = code_parse(req.params.id)
      user_id = parseInt(req.params.user_id)
      _l = (text)=> locale._(text, language)
      config_get('dbmemory').random_get Anonymous::_module(), code, (params)=>
        if ! (params and params.user_id is user_id)
          return res.send template_email_recovery({
            error: _l('UserNotify.Forget email link error')
          })
        if req.method is 'POST'
          password = req.body.pass
          if !password
            return res.send template_email_recovery({
              error: _l('UserNotify.Forget email link error')
            })
          AuthorizeEmail::_update_password {id: user_id, password}
          config_get('dbmemory').random_remove Anonymous::_module(), code
          return res.send template_email_recovery({
            success: _l('UserNotify.Forget email success')
          })

        res.send template_email_recovery({
          password: _l('UserNotify.Forget email password')
          button: _l('UserNotify.Forget email button')
        })

module.exports.index = (app, locales, template_file = 'index', url = '')->
  index = locales.reduce (acc, language)->
    Object.assign acc, {
      [language]: template.generate
        template: template_file
        language: language
        locales: locales
        _l: (v)-> locale._(v, language)
      }
  , {}
  locales.forEach (language, i)->
    app.get '/' + [ (if i > 0 then language else ''), url ].filter( (p)-> !!p ).join('/'), (req, res)->
      res.send index[language]


module.exports.payments = (app)->
  transaction =
    callback: (id, platform, callback)=>
      new (Authorize[platform])().buy_complete id, (params)=>
        User::_buy_callback(Object.assign {platform}, params)
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
          params = do =>
            if !req.body
              return null
            if req.body.object is 'payments'
              if req.body.entry.length isnt 1
                console.info 'facebook payment', req.body.entry
                return null
              return {id: req.body.entry[0].id}
            if req.body.object is 'payment_subscriptions'
              return {id: req.body.entry[0].id, subscription: true}
            return null
          if !params
            return res.sendStatus(404)
          transaction.callback params, platform, (err)->
            if err
              console.info 'facebook payment', err, JSON.stringify(req.body)
              if err isnt 'incompleted'
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
  if config_get('inbox')
    app.use bodyParser.json {
      type: (req)->
        if req.url.indexOf("/#{config_get('inbox').transaction}") >= 0
          return false
        return typeis(req, 'application/json')
    }
    do =>
      transaction_url = config_get('inbox').transaction_completed
      template = template_local('inbox-callback')
      ['en', 'ru', 'lv'].forEach (language)=>
        template_generated = template { text: locale._( 'Inbox transaction completed', language ) }
        app.get "#{transaction_url}#{language}.html", (req, res)->
          res.send template_generated


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
      if !(data and Array.isArray(data) and data[0] and typeof data[0] is 'string')
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
