module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
PubsubServerObjects = require('./default').PubsubServerObjects


User = null
config_callback( ->
  User = module_get('server.room.user').User
)()


module.exports.Users = class Users extends PubsubServerObjects
  _module: 'users'
  model: -> User

  _check_duplicate: (id)->
    model = @get(id)
    if model
      model.remove('duplicate')

  _add: (ob, server, server_self)->
    if not server_self
      @_check_duplicate(ob.id)
    super ...arguments

  _create: (attributes)->
    @_check_duplicate(attributes.id)
    super ...arguments

  publish_menu: (event, params)->
    @_objects.forEach (ob)->
      if !ob.room
        ob.publish(event, params)
