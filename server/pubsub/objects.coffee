PubsubServer = require('../pubsub/multiserver').PubsubServer


module.exports.PubsubServerObjects = class PubsubServerObjects extends PubsubServer
  constructor: ->
    super()
    @_objects = []
    @_all = []

  _add: (options)->
    @_all.push options
    @trigger 'add', options

  _remove: (id)->
    index = @_all.findIndex (ob)-> ob.id is id
    @_all.splice(index, 1)
    @trigger 'remove', {id}

  _update: (params)->
    index = @_all.findIndex (ob)-> ob.id is params.id
    @_all[index] = Object.assign {}, @_all[index], params
    @trigger 'update'

  get: (id, index=false)->
    @_objects[if index then 'findIndex' else 'find'] (ob)-> ob.id is id

  _objects_exec: (params)->
    filter = params.filter
    for fn, args of params
      if fn is 'filter'
        continue
      @_objects.forEach (o)->
        if filter
          data = o.data_public()
          for key, value of filter
            if value isnt data[key]
              return
        o[fn](args)

  _object_exec: (id, method, ...args)->
    ob = @get()
    if ob
      return ob[method].apply ob, args
    model = @model()
    model::emit_self_exec.apply model::, arguments

  _create: (options)->
    model = new (@model())(options, @)
    model.parent = @
    @_objects.push model
    @emit_immediate_exec '_add', model.data_public()
    model.bind 'remove', =>
      @_objects.splice @get(model.id, true), 1
      @emit_immediate_exec '_remove', model.id
    model.bind 'update', (pr)=> @emit_immediate_exec '_update', Object.assign( {id: model.id}, pr )
    model
