module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
PubsubServer = require('./default').PubsubServer


Room = null
User = null
config_callback( ->
  Room = module_get('server.room.room').Room
  User = module_get('server.room.user').User
)()


module.exports.Rooms = class Rooms extends PubsubServer
  _module: 'rooms'
  model: -> Room
  constructor: ->
    @_lobby = []
    @_models = []
    super

  _lobby_index: (id)-> @_lobby.findIndex (u)-> u.id is id

  lobby_add: (params)->
    if @_lobby_index(params.id) >= 0
      return
    @_lobby.push params
    User::emit_self_exec params.id, 'lobby_join', {rooms: @_module}

  lobby_remove: (id)->
    index = @_lobby_index(id)
    if index < 0
      return
    @_lobby.splice(index, 1)
    User::emit_self_exec id, 'lobby_remove', {rooms: @_module}

  _create: (attributes)->
    room = new (@model())(attributes)
    @_models.push room
    room.bind 'remove', =>
      @_models.splice @_models.findIndex( (m)-> m.id() is room.id()), 1
    room
