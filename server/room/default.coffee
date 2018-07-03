PubsubServer = require('../pubsub/multiserver').PubsubServer


module.exports.PubsubServer = class PubsubServer2 extends PubsubServer
  constructor: ->
    @_objects = []
    @_all = []
    super

  _add: (attributes)->
    @_all.push attributes
    @trigger 'add'

  _remove: (id)->
    index = @_all.findIndex (ob)-> ob.id is id
    @_all.splice(index, 1)
    @trigger 'remove'

  get: (id, index=false)->
    @_objects[if index then 'findIndex' else 'find'] (ob)-> ob.id() is id

  _create: (attributes)->
    model = new (@model())(attributes)
    @_objects.push model
    @emit_immediate_exec '_add', model.data_public()
    model.bind 'remove', =>
      @_objects.splice @get(attributes.id, true), 1
      @emit_immediate_exec '_remove', model.id()
    model
