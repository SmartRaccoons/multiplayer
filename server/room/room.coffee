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

  constructor: (@attributes)->
    @_id = "#{config_get('server_id')}:#{_ids++}"
    super
    @users = []
    if @attributes.users
      @attributes.users.forEach (user)=> @user_add(user)

  id: -> @_id

  _game_start: ->
    @_game = new (@game) Object.assign {}, @attributes, {users: @users.map (u)-> u.id}

  emit_user_publish: -> User::emit_self_publish.apply @, arguments

  emit_users_publish: ->
    args = Array.from(arguments)
    @users.forEach (user)=>
      @emit_user_publish.apply @, [user.id].concat(args)

  _game_exec: ({user_id, method, params})->
    if not (@_game and @game_methods[method] and
      (('waiting' of @game_methods[method] and !@game_methods[method].waiting) or @_game.waiting() is user_id )
    )
      return
    @_game[method](Object.assign({user_id}, params))

  user_add: (user)->
    @users.push user

  user_get: (id, index = false)-> @users[if index then 'findIndex' else 'find']( (u)-> u.id is id )

  user_remove: (id)->
    @users.splice(@user_get(id, true), 1)
