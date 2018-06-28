module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
PubsubModule = require('../pubsub/multiserver').PubsubModule


Login = null
class User extends PubsubModule

config_callback( ->
  Authorize = module_get('server.room.authorize')
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
  _module: 'user'
  constructor: (attr)->
    @attributes = Object.assign({alive: new Date()}, attr)
    super
    @_bind_socket()
    @

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
    @attributes.socket.remove_callback = (immediate)=>
      if immediate
        @remove()

  id: -> @attributes.id

  alive: -> @get('alive').getTime() > new Date().getTime() - (if @room then 60 else 10) * 60 * 1000

  room_set: (room_id)->
    @room = room_id

  room_remove: ->
    @room = null
    @publish 'rooms:remove'

  room_exec: ->
    if !@room
      return
    @emit_module_exec.apply @,  ['room', @room].concat(arguments...)

  publish: (ev)-> @attributes.socket.send.apply(@attributes.socket, if Array.isArray(ev) then ev else arguments)

  data: -> _pick @attributes, @_attr

  data_public: -> _pick @attributes, @_attr_public

  set: (params, silent=false)->
    Object.assign @attributes, params
    if 'socket' of params
      @_bind_socket()
    data = _pick params, @_attr
    if Object.keys(data).length is 0
      return
    @publish 'user:set', data
    if !silent
      Login::_user_update(Object.assign({id: @id()}, data))

  get: (param)-> @attributes[param]

  remove: ->
    @room_exec('remove_user', @id())
    super
