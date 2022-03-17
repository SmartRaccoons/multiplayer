redis = require('redis')
SimpleEvent = require('simple.event').SimpleEvent


__circle_server = 0
__circle_server_slave = 0

module.exports.Pubsub = class Pubsub
  _events:
    all_exec: (module)-> "server:#{module}:exec"
    server_exec: (module, server)-> "server:#{module}:exec:#{@options.server_all[server]}"
    module_exec: (module, id)-> "servermodule:#{module}:exec:#{id}"

  constructor: (@options)->
    @_events_holder = new SimpleEvent()
    @pub = redis.createClient(@options.redis)
    @sub = redis.createClient(@options.redis)
    for event, callback of @_events
      @["on_#{event}"] = do (event, callback)->
        (module)->
          callback_args = [
            module._module()
            if event is 'module_exec' then module.id else @options.server_id
          ]
          module.on_to @, callback.apply(@, callback_args), (data)=>
            module[data.method].apply(module, data.params)

      @["emit_#{event}"] = do (event, callback)->
        callback_args = callback.length
        ->
          args = Array::slice.call(arguments)
          args_other = args.slice(callback_args)
          callback_emit = args_other.pop() if typeof args_other[args_other.length - 1] is 'function'
          @emit.call @, callback.apply(@, args.slice(0, callback_args)), {method: args_other[0], params: args_other.slice(1)}, callback_emit
    @sub.on 'message', (ch, message)=>
      m = JSON.parse message, (key, value)->
        if typeof(value) is 'string'
          regexp = /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d.\d\d\dZ$/.exec(value);
          if regexp
            return new Date(value)
        return value
      @_events_holder.emit ch, m.data, m.server, m.server is @options.server_id

  on: (event, fn)->
    @_events_holder.on event, fn
    @sub.subscribe(event)

  emit: (event, data, callback=->)->
    @pub.publish(event, JSON.stringify({data: data, server: @options.server_id}), callback)

  off: (event)->
    @_events_holder.off event
    if !@_events_holder._events[event]
      @sub.unsubscribe(event)

  emit_server_master_exec: (module, method)->
    @emit_server_exec.apply @, [module, 0, method].concat Array::slice.call(arguments, 2)

  emit_server_slave_exec: (module, method)->
    for i in [1...@options.server_all.length]
      @emit_server_exec.apply @, [module, i, method].concat Array::slice.call(arguments, 2)

  emit_server_circle_exec: (module, method)->
    @emit_server_exec.apply @, [module, __circle_server, method].concat Array::slice.call(arguments, 2)
    __circle_server = (__circle_server + 1) % @options.server_all.length

  emit_server_circle_slave_exec: (module, method)->
    if @options.server_all.length <= 1
      __circle_server_slave = 0
    else if __circle_server_slave is 0
      __circle_server_slave = 1
    @emit_server_exec.apply @, [module, __circle_server_slave, method].concat Array::slice.call(arguments, 2)
    __circle_server_slave = (__circle_server_slave + 1) % @options.server_all.length

  emit_server_other_exec: (module, method)->
    for i in [0...@options.server_all.length]
      if i isnt @options.server_id
        @emit_server_exec.apply @, [module, i, method].concat Array::slice.call(arguments, 2)


module.exports.PubsubDev = class PubsubDev extends Pubsub
  on: (event)->
    console.info "--------on #{event} #{@options.server_id}"
    super ...arguments

  emit: (event, params)->
    console.info "--------emit #{event} #{JSON.stringify(params)} #{@options.server_id}"
    super ...arguments

  off: (event)->
    console.info "--------off #{event} #{@options.server_id}"
    super ...arguments
