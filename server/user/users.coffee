module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
PubsubServerObjects = require('../pubsub/objects').PubsubServerObjects


User = null
config_callback( ->
  User = module_get('server.user').User
)()


module.exports.Users = class Users extends PubsubServerObjects
  _module: 'users'
  model: -> User

  _check_duplicate: (id)->
    model = @get(id)
    if model
      model.remove('duplicate')

  _create: (attributes)->
    @emit_immediate_exec '_check_duplicate', attributes.id
    super ...arguments

  publish_menu: (event, params)->
    @_objects.forEach (ob)->
      if !ob.room
        ob.publish(event, params)
