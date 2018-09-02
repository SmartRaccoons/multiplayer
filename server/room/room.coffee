PubsubModule = require('../pubsub/multiserver').PubsubModule
config_get = require('../../config').config_get
config_callback = require('../../config').config_callback
module_get = require('../../config').module_get


User = null
config_callback( ->
  User = module_get('server.room.user').User
)()


_ids = 1
exports.Room = class Room extends PubsubModule
  _module: 'room'
  game: class Game
    constructor: -> throw 'no game class'
  # game_methods:
  #   method:
  #     waiting: false
  #     validate: (v)->
  #       v = parseInt(v.pit)
  #       if 0 <= v.pit <= 5
  #          return {pit: v.pi}
  #        return false
  #

  constructor: (attributes)->
    super({id: "#{config_get('server_id')}:#{_ids++}"})
    @attributes = attributes
    @users = []
    @spectators = []
    @_disconected = []
    if @attributes.users
      @attributes.users.forEach (user)=> @user_add(user)

  _game_start: (attributes)->
    @_game = new (@game) Object.assign {}, attributes, {users: @users.map (u)-> u.id}

  _exec_user: -> User::emit_self_exec.apply User::, arguments

  _publish_user: (user_id)->
    if @_disconected.indexOf(user_id) >= 0
      return
    User::emit_self_publish.apply User::, arguments

  publish: (ev, pr, pr_additional = [])->
    additional = pr_additional.reduce ( (acc, v)-> Object.assign acc, {[v[0]]: v[1]} ), {}
    @users
    .concat(@spectators)
    .forEach (user)=>
      @_publish_user.apply @, [user.id].concat [ ev, if additional[user.id] then Object.assign({}, pr, additional[user.id]) else pr ]

  _game_exec: ({user_id, method, params})->
    if not (@_game and @game_methods[method] and
      (@user_get(user_id, true) >= 0) and
      (('waiting' of @game_methods[method] and !@game_methods[method].waiting) or @_game.waiting() is user_id )
    )
      return
    @_game[method](Object.assign({user_id}, params))

  user_add: (user)->
    @users.push user
    @_exec_user(user.id, '_room_add', {id: @id, type: 'user'})

  user_exist: (user_id)-> @user_get(user_id, true) >= 0

  user_get: (id, index = false)-> @users[if index then 'findIndex' else 'find']( (u)-> u.id is id )

  user_reconnect: (id)->
    do =>
      index = @_disconected.indexOf(id)
      if index >= 0
        @_disconected.splice(index, 1)
    type = null
    if @user_exist(id)
      type = 'user'
    else if @spectator_exist(id)
      type = 'spectator'
    else
      return false
    @_exec_user(id, '_room_add', {id: @id, type})
    return true

  user_remove: ({id, disconnect})->
    if disconnect
      @_disconected.push id
      return
    if @user_exist(id)
      @users.splice(@user_get(id, true), 1)
    else if @spectator_exist(id)
      @spectators.splice(@spectator_get(id, true), 1)
    @_exec_user(id, '_room_remove', @id)

  user_to_spectator: (id)->
    @spectators.push @users.splice(@user_get(id, true), 1)[0]
    @_exec_user(id, '_room_update', {id: @id, type: 'spectator'})

  spectator_exist: (id)-> @spectator_get(id, true) >= 0

  spectator_get: (id, index = false)-> @spectators[if index then 'findIndex' else 'find']( (u)-> u.id is id )

  data_public: -> {id: @id}

  remove: ->
    @users
    .concat(@spectators)
    .map (u)-> u.id
    .forEach (id)=>
      @user_remove({ id })
    super()
