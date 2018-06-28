module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
PubsubServer = require('../pubsub/multiserver').PubsubServer


User = null
config_callback( ->
  User = module_get('server.room.user').User
)()


module.exports.Users = class Users extends PubsubServer
  _module: 'users'
  constructor: ->
    @_objects = []
    @_all = []
    super

  _check_duplicate: (id)->
    model = @get(id)
    if model
      model.attributes.socket.disconnect('duplicate')

  _add: (ob, server, server_self)->
    if not server_self
      @_check_duplicate(ob.id)
    @_all.push ob
    @trigger 'add'

  _remove: (id)->
    index = @_all.findIndex (ob)-> ob.id is id
    @_all.splice(index, 1)
    @trigger 'remove'

  get: (id, index=false)-> @_objects[if index then 'findIndex' else 'find'] (ob)-> ob.id() is id

  add_native: (attributes)->
    @_check_duplicate(attributes.id)
    model = new User(attributes)
    @emit_immediate_exec '_add', model.data_public()
    @_objects.push model
    model.bind 'remove', =>
      @_objects.splice @get(attributes.id, true), 1
      @emit_immediate_exec '_remove', model.id()
    model

  publish_menu: (event, params)->
    @_objects.forEach (ob)->
      if !ob.room
        ob.publish(event, params)
