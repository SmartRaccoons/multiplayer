module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
PubsubServerObjects = require('../pubsub/objects').PubsubServerObjects


Room = null
User = null
config_callback ->
  Room = module_get('server.room').Room
  User = module_get('server.user').User


module.exports.Rooms = class Rooms extends PubsubServerObjects
  model: -> Room

  constructor: ->
    super()
    @_lobby = []

  _lobby_index: (id)-> @_lobby.findIndex (u)-> u.id is id

  _lobby_check: (params)-> @_lobby_index(params.id) < 0

  _lobby_params: (params)-> {module: @_module()}

  lobby_add: (params)->
    if !@_lobby_check ...arguments
      return false
    @_lobby.push(params)
    @emit_user_exec params.id, '_lobby_add', @_lobby_params(params)
    return true

  lobby_remove: ({id}, params = {silent: false})->
    index = @_lobby_index(id)
    if index < 0
      return false
    lobby = @_lobby.splice(index, 1)[0]
    if !params.silent
      @emit_user_exec id, '_lobby_remove', @_lobby_params(lobby)
    return lobby

  emit_user_exec: -> User::emit_self_exec.apply User::, arguments

  emit_user_publish: -> User::emit_self_publish.apply User::, arguments
