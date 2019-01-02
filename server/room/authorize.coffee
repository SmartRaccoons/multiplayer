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
  if config_get('draugiem')
    ApiDraugiem::app_id = config_get('draugiem').key
    config.draugiem =
      buy_transaction: config_get('draugiem').buy_transaction
  if config_get('inbox')
    config.inbox =
      buy_price: config_get('inbox').buy_price
    inbox = new ApiInbox(config_get(['inbox', 'server']))
  if config_get('google')
    google = new ApiGoogle(config_get(['google', 'server']))


module.exports.Login = class Login
  _attr:
    'id': {db: true}
    'name': {default: '', db: true}
    'language': {db: true, private: true}
    'draugiem_uid': {db: true, private: true}
    'facebook_uid': {db: true, private: true}
    'google_uid': {db: true, private: true}
    'inbox_uid': {db: true, private: true}
    'img': {default: '', db: true}

    'new': {private: true}

  _table: 'auth_user'

  _user_get: (where, update, callback)->
    if !callback
      callback = update
      update = {}
    config.db.select_one
      select: Object.keys(@_attr).filter (v)=> @_attr[v].db
      table: @_table
      where: where
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
      if item isnt 'id' and @_attr[item].db
        result[item] = update[item]
      return result
    , {}
    if Object.keys(data).length > 0
      config.db.update
        table: @_table
        data: data
        where: {id: update.id}

  _user_create: (data, callback)->
    data.language = @_attr.language.validate(data.language)
    data = Object.assign Object.keys(@_attr).reduce( (result, item)=>
      if @_attr[item].db and 'default' of @_attr[item]
        result[item] = @_attr[item].default
      result
    , {}), data
    config.db.insert
      table: @_table
      data: Object.assign({last_login: new Date(), date_joined: new Date()}, data)
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
          sign: ['>', new Date(new Date().getTime() - 1000 * 60 * 60 * 24 * 30) ]
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
    if !(params.service of config.buy)
      return
    config.db.insert
      table: @_table_transaction
      data: Object.assign {created: new Date()}, params
    , (id)=> callback({id})

  _transaction_get: (where, callback_save, callback_end)->
    config.db.select_one
      table: @_table_transaction
      where: Object.assign({fulfill: '0'}, where)
    , (data)=>
      if !data
        return callback_end('transaction not found')
      callback_save
        complete: =>
          config.db.update
            table: @_table_transaction
            where: {id: data.id}
            data: {fulfill: '1', fulfilled: new Date()}
          , -> callback_end()
        transaction_id: data.id
        user_id: data.user_id
        service: data.service


module.exports.facebook = class LoginFacebook extends Login
  _table_session: 'auth_user_session_facebook'
  _table_transaction: 'transaction_facebook'
  _api_call: ({code}, callback)->
    fbgraph.setAccessToken(code)
    fbgraph.get '/me?fields=locale,name,picture.width(100)', (err, res)=>
      if err
        return callback(null)
      callback({facebook_uid: res.id}, {name: res.name, language: res.locale, img: if res.picture and res.picture.data then res.picture.data.url else null})

  buy: (params, callback)->
    @_transaction_create params, callback

  buy_complete: (id, callback_save, callback_end)->
    fbgraph.get "/#{id}?fields=request_id,user,actions,items&access_token=#{config.facebook.id}|#{config.facebook.key}", (err, res)=>
      if err
        return callback_end(err)
      if res.actions[0].status isnt 'completed'
        return callback_end "incompleted: #{id}"
      @_transaction_get {id: res.request_id}, callback_save, callback_end


module.exports.google = class LoginGoogle extends Login
  _table_session: 'auth_user_session_google'
  _api_call: (params, callback)->
    google.authorize params, (user)=>
      if not user
        return callback(null)
      callback({google_uid: user.uid}, {language: user.language, name: user.name, img: user.img})


module.exports.draugiem = class LoginDraugiem extends Login
  _table_session: 'auth_user_session_draugiem'
  _table_transaction: 'transaction_draugiem'

  buy: ({service, user_id}, callback)->
    if !(service of config.draugiem.buy_transaction)
      return
    @api.transactionCreate config.draugiem.buy_transaction[service], null, (transaction)=>
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
        service: service
        user_id: user_id
      , => callback({link: transaction.link})

  buy_complete: (transaction_id, callback_save, callback_end)->
    @_transaction_get {transaction_id}, callback_save, callback_end
