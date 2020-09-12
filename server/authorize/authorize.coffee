crypto = require('crypto')
uuidv4 = require('uuid').v4
fbgraph = require('fbgraph')
ApiGoogle = require('../api/google').ApiGoogle
ApiInbox = require('../api/inbox').ApiInbox
ApiDraugiem = require('../api/draugiem').ApiDraugiem

config_get = require('../../config').config_get
config_callback = require('../../config').config_callback


config = {}
inbox = null
google = null
config_callback ->
  config.db = config_get('db')
  config.buy = config_get('buy')
  if config_get('facebook')
    config.facebook =
      id: config_get('facebook').id
      key: config_get('facebook').key
      buy_price: config_get('facebook').buy_price
  if config_get('draugiem')
    ApiDraugiem::app_id = config_get('draugiem').key
    config.draugiem =
      buy_transaction: config_get('draugiem').buy_transaction
      buy_price: config_get('draugiem').buy_price
  if config_get('inbox')
    config.inbox =
      buy_price: config_get('inbox').buy_price
    inbox = new ApiInbox(config_get(['inbox', 'server']))
  if config_get('google')
    google = new ApiGoogle(config_get(['google', 'server', 'code_url']))
  if config_get('email')
    config.email = config_get('email')


module.exports.Login = class Login
  _opt:
    'id': {db: true, public: true}
    'name': {default: '', db: true, public: true}
    'language': {db: true}
    'draugiem_uid': {db: true}
    'facebook_uid': {db: true}
    'google_uid': {db: true}
    'inbox_uid': {db: true}
    'img': {default: '', db: true, public: true}
    # 'params':
    #   parse:
    #     to: JSON.stringify
    #     from: JSON.parse
    'new': {}
    'date_joined': {db: true, default: -> new Date()}

  _table: 'auth_user'

  _parse: ->
    Object.keys(@_opt)
    .filter (v)=> !!@_opt[v].parse
    .map (v)=> [v, @_opt[v].parse]

  _user_get: (where, update, callback)->
    if !callback
      callback = update
      update = {}
    config.db.select_one
      select: Object.keys(@_opt).filter (v)=> @_opt[v].db
      table: @_table
      where: where
      parse: @_parse()
    , (user)=>
      if !user
        return callback(null)
      user = Object.assign({new: false}, user, update)
      callback(user)
      config.db.update
        table: @_table
        data: Object.assign({last_login: new Date()}, update)
        where: {id: user.id}

  _user_update: (update)->
    data = Object.keys(update).reduce (result, item)=>
      if item isnt 'id' and @_opt[item].db
        result[item] = update[item]
      return result
    , {}
    if Object.keys(data).length > 0
      config.db.update
        table: @_table
        data: data
        where: {id: update.id}
        parse: @_parse()

  _user_create: (data, callback)->
    data.language = @_opt.language.validate(data.language)
    data = Object.assign Object.keys(@_opt).reduce( (result, item)=>
      if @_opt[item].db and 'default' of @_opt[item]
        result[item] = if typeof @_opt[item].default is 'function' then @_opt[item].default() else @_opt[item].default
      result
    , {}), data
    config.db.insert
      table: @_table
      data: Object.assign {last_login: new Date()}, data
      parse: @_parse()
    , (id)-> callback(Object.assign({id: id, new: true}, data))

  _user_create_or_update: (where, data, callback)->
    #omit language update
    data_get = Object.assign {}, data
    delete data_get.language
    @_user_get where, data_get, (user)=>
      if user
        return callback(user)
      @_user_create Object.assign(where, data), callback

  _user_session_check: (code, callback)->
    config.db.select_one
      table: @_table_session
      where:
        code: code
        last_updated:
          date: -30
    , (session)=>
      if !session
        return callback()
      @_user_get {id: session.user_id}, (user)=> callback(user, session)
      config.db.update
        table: @_table_session
        data: {last_updated: new Date()}
        where: {id: session.id}

  _user_session_save: (params)->
    config.db.insert
      table: @_table_session
      data: Object.assign({last_updated: new Date()}, params)

  _api_session: ->

  authorize: (params, callback)->
    code = params.code
    @_user_session_check code, (user, session)=>
      if user
        @_api_session(session)
        return callback(user)
      @_api_call params, (where, user, session={})=>
        if not where
          return callback(null)
        @_user_create_or_update where, user, (user)=>
          callback(user)
          @_user_session_save Object.assign({user_id: user.id, code}, session)

  _transaction_create: (params, callback)->
    config.db.insert
      table: @_table_transaction
      data: Object.assign {created: new Date()}, params
    , (id)=> callback({id})

  _transaction_get: (where, callback_save, callback_end)->
    config.db.select_one
      table: @_table_transaction
      where: where
    , (data)=>
      if !data
        return callback_end('transaction not found')
      subscription = config.buy.subscription and data.service in Object.keys(config.buy.subscription)
      if data.fulfill > 0 and !subscription
        return callback_end('transaction already completed')
      callback_save
        complete: =>
          config.db.update
            table: @_table_transaction
            where: {id: data.id}
            data: {fulfill: data.fulfill + 1, fulfilled: new Date()}
          , -> callback_end()
        transaction:
          id: data.id
          service: data.service
        user_id: data.user_id


module.exports.cordova = class LoginCordova extends Login
  _table_transaction: 'transaction_cordova'

  buy_complete: (params, callback_save, callback_end)->
    @_transaction_get params, callback_save, (error)=>
      if error is 'transaction not found'
        return @_transaction_create params, ({id})=>
          @_transaction_get {id}, callback_save, callback_end
      return callback_end(error)


module.exports.facebook = class LoginFacebook extends Login
  _name: 'facebook'
  _table_session: 'auth_user_session_facebook'
  _table_transaction: 'transaction_facebook'
  _api_call: ({code}, callback)->
    fbgraph.setAccessToken(code)
    fbgraph.get '/me?fields=token_for_business,locale,name,picture.width(100)', (err, res)=>
      if err
        return callback(null)
      callback({facebook_uid: res.id}, {facebook_token_for_business: res.token_for_business, name: res.name, language: res.locale, img: if res.picture and res.picture.data then res.picture.data.url else null})

  buy: (params, callback)->
    if !(params.service of config.facebook.buy_price)
      return
    @_transaction_create params, callback

  buy_complete: ({ id, subscription }, callback_save, callback_end)->
    fbgraph.get "/#{id}?fields=#{if subscription then 'status,next_period_product,next_bill_time,user' else 'request_id,user,actions,items'}&access_token=#{config.facebook.id}|#{config.facebook.key}", (err, res)=>
      if err
        return callback_end(err)
      if !subscription
        if res.actions[0].status isnt 'completed'
          return callback_end "incompleted"
        @_transaction_get {id: res.request_id}, callback_save, callback_end
        return
      if res.status isnt 'active'
        return callback_end "status not active"
      @_user_get {facebook_uid: res.user.id}, (user)=>
        if !user
          return callback_end("user not found: #{res.user.id}")
        match = res.next_period_product.match( /\/\w+\-(\d+)\-\w+\.html/ )
        if !match
          return callback_end "service error: #{res.next_period_product}"
        service = match[1]
        if ! (user.facebook_subscriptions and user.facebook_subscriptions[service] is id)
          @_user_update
            id: user.id
            facebook_subscriptions: Object.assign {}, user.facebook_subscriptions, { [service]: id }
        if !config.buy.subscription[service]
          return callback_end("service not found: #{service}")
        expire = Math.ceil ( new Date(res.next_bill_time).getTime() - new Date().getTime() ) / ( 1000 * 60 * 60 * 24 )
        if expire <= 0
          return callback_end()
        callback_save
          complete: => callback_end()
          transaction:
            service: service
            expire: expire
          user_id: user.id


module.exports.google = class LoginGoogle extends Login
  _table_session: 'auth_user_session_google'
  _api_call: (params, callback)->
    google.authorize params, (user)=>
      if not user
        return callback(null)
      callback({google_uid: user.uid}, {language: user.language, name: user.name, img: user.img})


module.exports.draugiem = class LoginDraugiem extends Login
  _name: 'draugiem'
  _table_session: 'auth_user_session_draugiem'
  _table_transaction: 'transaction_draugiem'

  buy: ({service, user_id}, callback)->
    if !(service of config.draugiem.buy_transaction)
      return
    @api.transactionCreate config.draugiem.buy_transaction[service], Math.round(config.draugiem.buy_price[service] * 0.702804 ), (transaction)=>
      @_transaction_create
        transaction_id: transaction.id
        service: service
        user_id: user_id
      , => callback({link: transaction.link})

  buy_complete: (transaction_id, callback_save, callback_end)->
    @_transaction_get {transaction_id}, callback_save, callback_end

  _api_call: ({code}, callback)->
    @api = new ApiDraugiem()
    @api.authorize code, (user)=>
      callback {
        draugiem_uid: user['uid']
      }, {
        language: user['language']
        name: [user['name'], user['surname']].join(' ')
        img: if !user['img'] then null else user['img']
      }, {api_key: @api.app_key}
    , -> callback(null)

  _api_session: (session)->
    @api = new ApiDraugiem()
    @api.app_key = session.api_key


module.exports.inbox = class LoginInbox extends Login
  _name: 'inbox'
  _table_transaction: 'transaction_inbox'
  authorize: ({code, language}, callback)->
    where = {inbox_uid: code}
    @_user_get where, (user)=>
      if user
        return callback(user)
      inbox.authorize code, (res)=>
        @_user_create Object.assign(where, {name: res.name, language}), callback
      , => callback(null)

  buy: ({service, user_id, language}, callback)->
    if !(service of config.inbox.buy_price)
      return
    inbox.transaction_create config.inbox.buy_price[service], language, (transaction)=>
      @_transaction_create
        transaction_id: transaction.id
        language: transaction.language
        service: service
        user_id: user_id
      , ( => callback({link: transaction.link}) )

  buy_complete: (transaction_id, callback_save, callback_end)->
    @_transaction_get {transaction_id}, callback_save, callback_end


module.exports.email = class LoginEmail extends Login
  _name: 'email'
  _table_session: 'auth_user_session_email'

  _password: (msg)->
    crypto.pbkdf2Sync(msg, config.email.salt, 4096, 16, config.email.sha).toString('hex')

  _check_email: ({email}, callback)-> @_user_get {email}, callback

  _update_password: ({id, password})->
    @_user_update {id, password: @_password(password)}

  authorize: ({code, language}, callback)->
    if Array.isArray(code)
      [email, pass] = code
      return @_user_get {email}, (user)=>
        if !user
          return callback(null)
        if @_password(pass) isnt user.password
          return callback(null)
        session_code = [user.id, uuidv4()].join '-'
        callback(user, session_code)
        @_user_session_save {user_id: user.id, code: session_code}
    @_user_session_check code, (user)=> callback(user)
