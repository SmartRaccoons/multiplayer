module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
PubsubServerObjects = require('../pubsub/objects').PubsubServerObjects


Room = null
User = null
config_callback( ->
  Room = module_get('server.room').Room
  User = module_get('server.user').User
)()


module.exports.Rooms = class Rooms extends PubsubServerObjects
  _module: 'rooms'
  model: -> Room
  constructor: ->
    super()
    @_lobby = []
    @_models = []

  _lobby_index: (id)-> @_lobby.findIndex (u)-> u.id is id

  emit_user_exec: -> User::emit_self_exec.apply User::, arguments

  emit_user_publish: -> User::emit_self_publish.apply User::, arguments

  _lobby_params: -> {rooms: @_module, lobby: @_lobby.length}

  lobby_add: (params)->
    if @_lobby_index(params.id) >= 0
      return false
    @_lobby.push params
    @emit_user_exec params.id, '_lobby_add', @_lobby_params()
    return true

  lobby_remove: (id, silent = false)->
    index = @_lobby_index(id)
    if index < 0
      return
    @_lobby.splice(index, 1)
    if !silent
      @emit_user_exec id, '_lobby_remove', {rooms: @_module}
