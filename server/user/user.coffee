module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
config_get = require('../../config').config_get
PubsubModule = require('../pubsub/multiserver').PubsubModule
PubsubServer = require('../pubsub/multiserver').PubsubServer
Cordova = require('../api/cordova')
_invert = require('lodash').invert
_pick = require('lodash').pick


config = {}
cordova = null
Login = null
RoomModule = null
class User extends PubsubModule


Authorize = null
config_callback( ->
  config.db = config_get('db')
  config.cordova = config_get('cordova')
  config.android = config_get('android')
  config.ios = config_get('ios')
  config.buy = config_get('buy')
  if config.cordova
    cordova = new Cordova {
      android:
        email: config.android.email
        key: config.android.key
        packageName: config.cordova.id
      ios:
        shared_secret: config.ios.shared_secret
    }
  Authorize = module_get('server.authorize')
  RoomModule = module_get('server.room')
  User2 = module_get('server.user').User or User
  Login = Authorize.Login
  _opt = Authorize.Login::_opt
  User2::_opt = Object.keys(_opt)
  User2::_opt_public = Object.keys(_opt).filter (k)-> _opt[k].public
  User2::_opt_user = Object.keys(_opt).filter (k)-> !_opt[k].private
  if User2::_buy_params
    # User2::_buy_callback = ( {platform, user_id, transaction: {id: data.id, service: 'id from config', value: 'from config', subscription: boolean}, complete} )->
    User2::_buy_callback = ( { platform, user_id, transaction, complete } )->
      subscription = config.buy.subscription and transaction.service in Object.keys(config.buy.subscription)
      value = config.buy[if subscription then 'subscription' else 'product'][transaction.service]
      User2::emit_self_exec.apply User2::, [ user_id ].concat(
        if subscription then [
          'set_subscription', { field:  User2::_buy_params.subscription[value], expire: if !transaction.expire? then 32 else transaction.expire }
        ] else if transaction.service in User2::_buy_params.coins.service then [
          'set_coins', { coins: value, type: User2::_buy_params.coins.type }
        ] else [
          'set_product', { transaction: Object.assign { value }, transaction }
        ]
      ).concat( [ => complete() ])
)()

_pick = (ob, params)->
  Object.keys(ob).reduce (result, key)->
    if params.indexOf(key) >= 0
      result[key] = ob[key]
    result
  , {}


module.exports.User = class User extends User
  _alive_timeouts: [10 * 60, 60 * 60]
  _coins_history_params:
    table: 'coins_history'
    limit: 10
  # _buy_params:
  #   coins:
  #     type: 8
  #     sevice: ['1', '2']
  #   subscription: {value: field}
  _coins_bonus_params: {}
    # daily:
    #   after: 60 * 60 * 8
    #   type: 1
    #   coins: 150
  _message:
    table: 'user_message'
    limit: 10

  constructor: (options)->
    super({id: options.id})
    @options = Object.assign({alive: new Date()}, options)
    @_bind_socket()
    @publish 'authenticate:success', @data()
    Object.keys(@_coins_bonus_params).forEach (bonus)=> @_coins_bonus(bonus)
    @

  _message_check: ->
    config.db.select
      select: ['id', 'user_id', 'added', 'message']
      table: @_message.table
      limit: @_message.limit
      order: ['-added']
      where:
        user_id: [@options.id, null]
        added:
          sign: ['>', @options.date_joined]
        actual: [null, { sign: ['>', new Date()] }]
    , (rows)=>
      if rows.length is 0
        return
      config.db.select
        select: ['user_message_id']
        table: "#{@_message.table}_read"
        where:
          user_id: @options.id
          user_message_id: rows.map (row)-> row.id
        , (rows_read)=>
          read = rows_read.map (row_read)-> row_read.user_message_id
          @set
            messages: rows.map (row)->
              Object.assign {
                id: row.id
                intro: row.message.replace(/<[^>]*>?/gm, '').substr(0, 15)
                added: Math.round( ( row.added.getTime() - new Date().getTime() ) / 1000 )
              }, if row.id in read then {read: true}
    publish = (message)=> @publish 'user:message', message
    @options.socket.on 'user:message', (params)=>
      if ! (params and params.id and @options.messages)
        return
      message = @options.messages.find ({id})-> params.id is id
      if !message
        return
      if message.message
        return publish(message)
      config.db.select_one
        select: ['message']
        table: @_message.table
        where:
          id: message.id
      , (rows)=>
        if !rows
          return
        message.message = rows.message
        message.read = true
        publish(message)
        config.db.insert
          table: "#{@_message.table}_read"
          data:
            user_message_id: message.id
            user_id: @options.id
            added: new Date()

  __coins_bonus_check: (type, callback)->
    bonus = @_coins_bonus_params[type]
    config.db.select_one
      select: ['action', 'coins']
      table: @_coins_history_params.table
      where:
        user_id: @id
        type: bonus.type
      order: ['-action']
    , (result)=>
      left = Math.ceil( (bonus.after * 1000 + new Date(if result then result.action else 0).getTime() - new Date().getTime() ) / 1000 )
      params = if typeof bonus.coins is 'function' then bonus.coins.apply @, [ Object.assign( {left}, result ) ] else { coins: bonus.coins }
      if left < 0
        left = 0
      callback Object.assign { left }, params

  _coins_bonus: (type)->
    mt = "coins:bonus:#{type}"
    bonus = @_coins_bonus_params[type]
    publish = (params_additional={})=>
      @__coins_bonus_check type, (params)=>
        @publish mt, Object.assign {}, params, params_additional
    @options.socket.on mt, =>
      @__coins_bonus_check type, ({left, coins})=>
        params = {}
        if left is 0
          @set_coins {type: bonus.type, coins}
          params.reset = true
        publish(params)
    publish()

  emit_self_publish: (id, ev, params)-> @emit_self_exec.apply @, [id, 'publish', [ev, params]]

  _bind_socket: ->
    @options.socket.on 'alive', => @set({alive: new Date()})
    @options.socket.on 'user:update', (params)=>
      if !params
        return
      params_update = @_opt.reduce (result, opt)->
        if !!Login::_opt[opt].validate and params[opt]
          result[opt] = Login::_opt[opt].validate(params[opt])
        result
      , {}
      if Object.keys(params_update).length > 0
        @set(params_update)
    @options.socket.on 'game:*', (event, params)=>
      if !(@room and Object.keys(RoomModule[@room.module]::game_methods).indexOf(event) >= 0 and RoomModule[@room.module]::game_methods[event].validate)
        return
      params_new = RoomModule[@room.module]::game_methods[event].validate(params)
      if !params_new
        return
      @room_exec_game event, params_new
    @options.socket.on 'remove', => @remove()

  _bind_socket_cordova: ->
   @options.socket.on 'user:update:cordova', (params)=>
     if !(params and params.token)
       return
     config.db.replace
      table: 'auth_user_cordova_params'
      unique: ['user_id']
      data:
        user_id: @id
        token: params.token
        last_updated: new Date()

  _bind_socket_coins_buy: (platforms = ['facebook', 'draugiem', 'inbox'])->
    mt = 'buy'
    ['facebook', 'draugiem', 'inbox'].forEach (platform)=>
      if ! (platforms.indexOf(platform) >= 0 and @options.api._name is platform)
        return
      @options.socket.on "#{mt}:#{platform}", (args)=>
        if !args
          return
        service = args.service
        language = args.language
        @options.api.buy {service, user_id: @id, language}, (params)=>
          @publish "#{mt}:#{platform}", Object.assign({service}, params)

    if 'inbox_standalone' in platforms
      @options.socket.on "#{mt}:inbox_standalone", (args)=>
        if !args
          return
        service = args.service
        language = args.language
        new (Authorize.inbox)().buy {service, user_id: @id, language}, (params)=>
          @publish "#{mt}:inbox_standalone", Object.assign({service}, params)

    if 'cordova' in platforms
      @options.socket.on "#{mt}:cordova", (params)=> # id_local, product_id, service, transaction, platform
        if !( params and params.transaction and params.platform in ['ios', 'android'] )
          return
        if params.platform is 'android'
          if !params.product_id
            return
          service = _invert(config[params.platform].buy_transaction)[params.product_id]
          if !service
            return console.info "#{params.platform} #{params.product_id} #{@id} not found #{@id}"
          params.subscription = service in Object.keys(config.buy.subscription)

        cordova.payment_validate _pick(params, ['transaction', 'subscription', 'product_id', 'platform']), ({product_id, transaction_id, expire})=>
          service = _invert(config[params.platform].buy_transaction)[product_id]
          if !service
            return console.info "#{params.platform} #{product_id} not found #{@id}"
          new (Authorize.cordova)().buy_complete {
            platform: params.platform
            transaction_id
            service
            user_id: @id
          }, (params_transaction)=>
            @_buy_callback Object.assign({}, params_transaction, {
              platform: params.platform
              transaction: Object.assign {}, params_transaction.transaction, {
                expire: if expire then Math.ceil(expire / (1000 * 60 * 60 * 24) ) else expire
              }
            } )
          , =>
            @publish "#{mt}:cordova:finish", { id_local: params.id_local }

  _bind_socket_coins_history: ->
    mt = 'coins:history'
    cb = => @publish mt, @options.coins_history.map (v)->
      Object.assign {}, v, {
        action_seconds: Math.round( ( new Date(v.action).getTime() - new Date().getTime() ) / 1000 )
      }
    @options.socket.on mt, =>
      if @options.coins_history?
        return cb()
      config.db.select {
        table: @_coins_history_params.table
        where: {user_id: @id}
        limit: @_coins_history_params.limit
        order: ['-action']
        select: ['coins', 'action', 'type']
      }, (rows)=>
        @options.coins_history = rows
        cb()

  alive: -> @get('alive').getTime() > new Date().getTime() - @_alive_timeouts[ if @room then 1 else 0 ] * 1000

  _rooms_master_exe: (command, room = 'rooms', params={})->
    PubsubServer::_pubsub()['emit_server_master_exec'](room, command, @data_room(), params)

  rooms_lobby_add: (room = 'rooms', params={})-> @_rooms_master_exe 'lobby_add', room, params

  rooms_lobby_remove: ->
    if !@lobby
      return
    @_rooms_master_exe 'lobby_remove', @lobby.module

  rooms_reconnect: (room = 'rooms')->
    PubsubServer::_pubsub()['emit_all_exec'](room, '_objects_exec', {user_reconnect: @id})

  _lobby_add: (params)->
    @lobby = params
    @publish 'lobby:add', @lobby

  _lobby_remove: ->
    @publish 'lobby:remove', @lobby
    @lobby = null

  room_left: ->
    if @room and @room.type is 'spectator'
      @room_exec('user_remove', {id: @id})

  _room_add: (room)->
    @room = room
    @lobby = null
    @publish 'room:add', @room

  _room_remove: ->
    @publish 'room:remove', @room
    @room = null

  _room_update: (room)->
    if !@room
      return
    @room = Object.assign {}, @room, room
    @publish 'room:update', room

  room_exec: ->
    if !@room
      return
    RoomModule[@room.module]::emit_self_exec.apply RoomModule[@room.module]::, [@room.id].concat(Array::slice.call(arguments))

  room_exec_game: (method, params)-> @room_exec '_game_exec', {user_id: @id, method, params}

  publish: (ev)-> @options.socket.send.apply(@options.socket, if Array.isArray(ev) then ev else arguments)

  data: -> _pick @options, @_opt_user

  data_public: -> _pick @options, @_opt_public

  data_room: -> @data_public()

  _set_db: (params)-> Login::_user_update(params)

  set: (params, silent = false)->
    Object.assign @options, params
    if 'socket' of params
      @_bind_socket()
    data = _pick params, @_opt
    if Object.keys(data).length is 0
      return null
    if !silent
      @_set_db Object.assign({id: @id}, params)
    @publish 'user:update', data

  set_ifoffline: (id, params)-> @_set_db(Object.assign({id}, params))

  _set_coins_db: ({user_id, coins, type})->
    config.db.insert
      table: @_coins_history_params.table
      data: {user_id, action: new Date(), coins, type}

  set_coins: ({coins, type})->
    @set {coins: @options.coins + coins}
    if @options.coins_history?
      @options.coins_history.unshift {coins, type, action: new Date()}
    @_set_coins_db {user_id: @id, coins, type}

  set_coins_ifoffline: (id, {coins, type})->
    @_set_db({id, coins: {increase: coins}})
    @_set_coins_db {user_id: id, coins, type}

  set_product: (transaction)->
    throw 'product in transaction missing'
  set_product_ifoffline: (transaction)->
    throw 'product in transaction missing'

  set_subscription: ({field, expire})->
    @set { [field]: expire }

  set_subscription_ifoffline: (id, {field, expire})->
    @_set_db { id, [field]: expire }

  get: (param)-> @options[param]

  remove: (reason)->
    if @_removed
      return
    @_removed = true
    @room_exec('user_remove', {@id, disconnect: true})
    super()
    @options.socket.disconnect(reason)
