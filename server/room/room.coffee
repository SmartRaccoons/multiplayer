PubsubModule = require('../pubsub/multiserver').PubsubModule
config_get = require('../../config').config_get
config_callback = require('../../config').config_callback
module_get = require('../../config').module_get


User = null
config_callback ->
  User = module_get('server.user').User


_ids = 1
exports.Room = class Room extends PubsubModule
  _messages_enable: false
  game: class Game
    constructor: -> throw 'no game class'
  game_player_params: {id: 'id'}
  # game_methods:
  #   method:
  #     waiting: false
  #     validate: (v)->
  #       v = parseInt(v.pit)
  #       if 0 <= v.pit <= 5
  #          return {pit: v.pi}
  #        return false
  #

  constructor: (options)->
    super({id: if options.id then options.id else "#{config_get('server_id')}:#{_ids++}"})
    @options = options
    @users = []
    @spectators = []
    @_disconnected = []
    if @options.users
      @options.users.forEach (user)=> @user_add(user)

  _game_player_parse: (user)->
    Object.keys(@game_player_params).reduce (acc, v)=>
      if !(v of user)
        return acc
      Object.assign acc, if typeof @game_player_params[v] is 'function' then @game_player_params[v].bind(@)(user[v]) else {[@game_player_params[v]]: user[v]}
    , {}

  _game_start: (options)->
    @_game = new (@game) Object.assign {}, options, {
      players: @users.map (u)=> @_game_player_parse(u)
    }

  emit_user_exec: -> User::emit_self_exec.apply User::, arguments

  emit_user_publish: (user_id)->
    if user_id in @_disconnected
      return
    User::emit_self_publish.apply User::, arguments

  publish: (ev, pr, additional = {})->
    if Array.isArray(additional)
      additional = additional.reduce ( (acc, v)-> Object.assign acc, {[v[0]]: v[1]} ), {}
    @users
    .concat(@spectators)
    .forEach (user)=>
      @emit_user_publish.apply @, [user.id].concat [ ev, if additional and additional[user.id] then Object.assign({}, pr, additional[user.id]) else pr ]

  _message_add: ({user_id, message})->
    if !@_messages_enable
      return
    user = @user_get(user_id)
    user_type = 'user'
    if !user
      user = @spectator_get(user_id)
      user_type = 'spectator'
    if !user
      return
    @publish 'message:add', {
      user:
        name: user.name
        id: user.id
        type: user_type
      message: message
    }

  _game_exec: ({user_id, method, params, waiting_ignore})->
    if not (@_game and (waiting_ignore or @game_methods[method]) and
      (@user_get(user_id, true) >= 0) and
      (waiting_ignore or ('waiting' of @game_methods[method] and !@game_methods[method].waiting) or @_game.waiting() is user_id )
    )
      return
    @_game[method](Object.assign({user_id}, params))

  _disconnected_remove: (id)->
    index = @_disconnected.indexOf(id)
    if index >= 0
      @_disconnected.splice(index, 1)

  _disconnected_add: (id)->
    if !( id in @_disconnected )
      @_disconnected.push id

  user_add: (user)->
    if @user_exist user.id
      return false
    @_disconnected_remove(user.id)
    @users.push user
    @emit_user_exec(user.id, '_room_add', {id: @id, module: @_module(), type: 'user'})
    @emit 'update', {users: @users}
    return true

  user_exist: (user_id)-> @user_get(user_id, true) >= 0

  user_get: (id, index = false)-> @users[if index then 'findIndex' else 'find']( (u)-> u.id is id )

  user_reconnect: (id)->
    type = null
    if @user_exist(id)
      type = 'user'
    else if @spectator_exist(id)
      type = 'spectator'
    else
      return false
    @_disconnected_remove(id)
    @emit_user_exec(id, '_room_add', {id: @id, module: @_module(), type})
    return true

  user_remove: ({id, disconnect})->
    if disconnect
      @_disconnected_add(id)
      return
    @_disconnected_remove(id)
    if @user_exist(id)
      @users.splice(@user_get(id, true), 1)
      @emit 'update', {users: @users}
    else if @spectator_exist(id)
      @spectators.splice(@spectator_get(id, true), 1)
      @emit 'update', {spectators: @spectators}
    @emit_user_exec(id, '_room_remove', @id)

  user_to_spectator: (user)->
    if !@user_exist(user.id)
      return false
    @spectators.push @users.splice(@user_get(user.id, true), 1)[0]
    @emit_user_exec(user.id, '_room_update', {id: @id, module: @_module(), type: 'spectator'})
    @emit 'update', {users: @users, spectators: @spectators}
    return true

  spectator_exist: (id)-> @spectator_get(id, true) >= 0

  spectator_get: (id, index = false)-> @spectators[if index then 'findIndex' else 'find']( (u)-> u.id is id )

  data_public: -> {id: @id, users: @users, spectators: @spectators}

  remove: ->
    @users
    .concat(@spectators)
    .map (u)-> u.id
    .forEach (id)=>
      @user_remove({ id })
    super()
