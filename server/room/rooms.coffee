module_get = require('../../config').module_get
config_callback = require('../../config').config_callback
PubsubServer = require('./default').PubsubServer


Room = null
config_callback( ->
  Room = module_get('server.room.room').Room
)()


module.exports.Rooms = class Rooms extends PubsubServer
  _module: 'rooms'
  model: -> Room
