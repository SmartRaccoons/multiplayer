module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
config_get = require('../../config').config_get
PubsubModule = require('../pubsub/multiserver').PubsubModule
PubsubServer = require('../pubsub/multiserver').PubsubServer

config = {}
Login = null
RoomModule = null
class User extends PubsubModule

config_callback( ->
  config.db = config_get('db')
  Authorize = module_get('server.authorize')
  RoomModule = module_get('server.room')
  Login = Authorize.Login
  _attr = Authorize.Login::_attr
  User::_attr = Object.keys(_attr)
  User::_attr_public = Object.keys(_attr).filter (k)-> !_attr[k].private
)()

_pick = (ob, params)->
  Object.keys(ob).reduce (result, key)->
    if params.indexOf(key) >= 0
      result[key] = ob[key]
    result
  , {}


module.exports.User = class User extends User
  _coins_history_params:
    table: 'coins_history'
  _coins_bonus_params: {}
    # daily:
    #   after: 60 * 60 * 8
    #   type: 1
    #   coins: 150
  _module: 'user'
  constructor: (attributes)->
    super({id: attributes.id})
    @attributes = Object.assign({alive: new Date()}, attributes)
    @_bind_socket()
    @publish 'authenticate:success', @data()
    Object.keys(@_coins_bonus_params).forEach (bonus)=> @_coins_bonus(bonus)
    @

  __coins_bonus_check: (type, callback)->
    bonus = @_coins_bonus_params[type]
    config.db.select_one
      select: ['action']
      table: @_coins_history_params.table
      where:
        user_id: @id
        type: bonus.type
      order: ['-action']
    , (result)=>
      if !result
        return callback(0)
      left = Math.ceil( (bonus.after * 1000 + new Date(result.action).getTime() - new Date().getTime() ) / 1000 )
      if left < 0
        left = 0
      callback(left)

  _coins_bonus: (type)->
    mt = "coins:bonus:#{type}"
    bonus = @_coins_bonus_params[type]
    @__coins_bonus_check type, (left)=>
      @publish mt, {left, coins: bonus.coins}
      @attributes.socket.on mt, =>
        @__coins_bonus_check type, (left)=>
          if left is 0
            @set_coins {type: bonus.type, coins: bonus.coins}
            left = bonus.after
          @publish mt, {left, coins: bonus.coins}

  emit_self_publish: (id, ev, params)-> @emit_self_exec.apply @, [id, 'publish', [ev, params]]

  _bind_socket: ->
    @attributes.socket.on 'alive', => @set({alive: new Date()})
    @attributes.socket.on 'user:update', (params)=>
      if !params
        return
      params_update = @_attr.reduce (result, attr)->
        if !!Login::_attr[attr].validate and params[attr]
          result[attr] = Login::_attr[attr].validate(params[attr])
        result
      , {}
      if Object.keys(params_update).length > 0
        @set(params_update)
    @attributes.socket.on 'game:*', (event, params)=>
      if !(@room and params and Object.keys(RoomModule[@room.module]::game_methods).indexOf(event) >= 0 and RoomModule[@room.module]::game_methods[event].validate)
        return
      params_new = RoomModule[@room.module]::game_methods[event].validate(params)
      if !params_new
        return
      @room_exec_game event, params_new
    @attributes.socket.on 'remove', => @remove()

  _bind_socket_coins_history: ->
    mt = 'coins:history'
    cb = => @publish mt, @attributes.coins_history
    @attributes.socket.on mt, =>
      if @attributes.coins_history?
        return cb()
      config.db.select {
        table: @_coins_history_params.table
        where: {user_id: @id}
        limit: 10
        order: ['-action']
        select: ['coins', 'action', 'type']
      }, (rows)=>
        @attributes.coins_history = rows
        cb()

  alive: -> @get('alive').getTime() > new Date().getTime() - (if @room then 60 else 10) * 60 * 1000

  rooms_lobby_add: (room = 'rooms', params={})->
    PubsubServer::_pubsub()['emit_server_master_exec'](room, 'lobby_add', @data_public(), params)

  rooms_lobby_remove: (room = 'rooms')->
    pubsub = PubsubServer::_pubsub()
    pubsub.emit_server_master_exec.apply( pubsub, [room, 'lobby_remove', @id].concat(Array::slice.call(arguments, 1)) )

  rooms_reconnect: (room = 'rooms')->
    PubsubServer::_pubsub()['emit_all_exec'](room, '_objects_exec', {user_reconnect: @id})

  _lobby_add: (params)->
    @publish('lobby:add', params)

  _lobby_remove: (params)->
    @publish('lobby:remove', params)

  room_left: ->
    if @room and @room.type is 'spectator'
      @room_exec('user_remove', {id: @id})

  _room_add: (room)->
    @room = room
    @publish 'room:add', @room

  _room_remove: ->
    @room = null
    @publish 'room:remove'

  _room_update: (room)->
    @room = Object.assign {}, @room, room
    @publish 'room:update', room

  room_exec: ->
    if !@room
      return
    RoomModule[@room.module]::emit_self_exec.apply RoomModule[@room.module]::, [@room.id].concat(Array::slice.call(arguments))

  room_exec_game: (method, params)-> @room_exec '_game_exec', {user_id: @id, method, params}

  publish: (ev)-> @attributes.socket.send.apply(@attributes.socket, if Array.isArray(ev) then ev else arguments)

  data: -> _pick @attributes, @_attr

  data_public: -> _pick @attributes, @_attr_public

  _set_db: (params)-> Login::_user_update(params)

  set: (params, silent = false)->
    Object.assign @attributes, params
    if 'socket' of params
      @_bind_socket()
    data = _pick params, @_attr
    if Object.keys(data).length is 0
      return null
    if !silent
      @_set_db Object.assign({id: @id}, params)
    @publish 'user:set', data

  set_ifoffline: (id, params)-> @_set_db(Object.assign({id}, params))

  _set_coins_db: ({user_id, coins, type})->
    config.db.insert
      table: @_coins_history_params.table
      data: {user_id, action: new Date(), coins, type}

  set_coins: ({coins, type})->
    @set {coins: @attributes.coins + coins}
    if @attributes.coins_history?
      @attributes.coins_history.unshift {coins, type, action: new Date()}
    @_set_coins_db {user_id: @id, coins, type}

  set_coins_ifoffline: (id, {coins, type})->
    @_set_db({id, coins: {increase: coins}})
    @_set_coins_db {user_id: id, coins, type}

  get: (param)-> @attributes[param]

  remove: (reason)->
    if @_removed
      return
    @_removed = true
    @room_exec('user_remove', {@id, disconnect: true})
    super()
    @attributes.socket.disconnect(reason)
