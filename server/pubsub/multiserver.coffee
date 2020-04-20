config_get = require('../../config').config_get
SimpleEvent = require('simple.event').SimpleEvent


class Pubsub extends SimpleEvent
  _module: -> @.constructor.name

  _pubsub: -> config_get('pubsub')


module.exports.PubsubModule = class PubsubModule extends Pubsub
  ['emit_module_exec'].forEach (fn)->
    PubsubModule::[fn] = -> @_pubsub()[fn].apply(@_pubsub(), arguments)

  constructor: ({id})->
    super()
    @id = id
    @_pubsub().on_module_exec @

  emit_self_exec: (id, method, ...params)->
    if !@["#{method}_ifoffline"]
      return @emit_module_exec.apply(@, [@_module()].concat(Array::slice.call(arguments)))
    callback = if typeof params[params.length - 1] is 'function' then params.pop() else (->)
    @emit_module_exec.apply @, [@_module(), id, method].concat(params).concat(
      (err, count)=>
        if count is 0
          @["#{method}_ifoffline"].apply(@, [id].concat(params))
        callback(err, count)
    )


module.exports.PubsubServer = class PubsubServer extends Pubsub
  ['emit_all_exec', 'emit_server_exec', 'emit_server_master_exec',
    'emit_server_slave_exec', 'emit_server_circle_exec',
    'emit_server_other_exec', 'emit_server_circle_slave_exec'].forEach (fn)->
    PubsubServer::[fn] = -> @_pubsub()[fn].apply(@_pubsub(), [@_module()].concat(Array::slice.call(arguments)))

  constructor: ->
    super()
    ['on_all_exec', 'on_server_exec'].forEach (ev)=> @_pubsub()[ev] @

  emit_immediate_exec: (fn)->
    @[fn].apply(@, Array::slice.call(arguments, 1))
    @emit_server_other_exec.apply(@, arguments)
