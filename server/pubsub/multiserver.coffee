config_get = require('../../config').config_get
SimpleEvent = require('simple.event').SimpleEvent


class Pubsub extends SimpleEvent
  constructor: ->
    if not @_module
      throw "_module param required"

  _pubsub: -> config_get('pubsub')


module.exports.PubsubModule = class PubsubModule extends Pubsub
  constructor: ->
    super
    @_pubsub().on_module_exec @_module, @id(), (pr)=> @[pr.method](pr.params)

  emit_self_exec: -> @emit_module_exec.apply(@, [@_module].concat(arguments...))

  remove: ->
    super
    @_pubsub().remove_module_exec(@_module, @id())


['emit_module_exec'].forEach (fn)->
  PubsubModule::[fn] = -> @_pubsub()[fn].apply(@_pubsub(), arguments)


module.exports.PubsubServer = class PubsubServer extends Pubsub
  constructor: ->
    super
    ['on_all_exec', 'on_server_exec'].forEach (ev)=>
      @_pubsub()[ev] @_module, (pr)=> @[pr.method](pr.params)

['emit_all_exec', 'emit_server_exec', 'emit_server_master_exec', 'emit_server_slave_exec', 'emit_server_circle_exec'].forEach (fn)->
  PubsubServer::[fn] = -> @_pubsub()[fn].apply(@_pubsub(), [@_module].concat(arguments...))
