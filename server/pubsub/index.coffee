redis = require('redis')
EventEmitter = require('events').EventEmitter

circle_server = 0

module.exports.Pubsub = class Pubsub
  constructor: (@options)->
    @pub = redis.createClient(@options.redis)
    @sub = redis.createClient(@options.redis)
    @_event = new EventEmitter()
    @sub.on 'message', (ch, message)=>
      m = JSON.parse(message)
      @_event.emit ch, m.data, m.server, m.server is @options.server_id

  on: (event, fn)->
    @_event.on event, fn
    @sub.subscribe(event)

  on_all_exec: (module, callback)-> @on "server:#{module}:exec", callback

  on_server_exec: (module, callback)-> @on "server:#{module}:exec:#{@options.server_all[@options.server_id]}", callback

  on_module_exec: (module, id, callback)-> @on "server:#{module}:exec:#{id}", callback

  emit: (event, data, callback=->)->
    @pub.publish(event, JSON.stringify({data: data, server: @options.server_id}), callback)

  emit_all_exec: (module, method, params)-> @emit "server:#{module}:exec", {method, params}

  emit_server_exec: (module, server, method, params)-> @emit "server:#{module}:exec:#{@options.server_all[server]}", {method, params}

  emit_server_master_exec: (module, method, params)-> @emit_server_exec(module, 0, method, params)

  emit_server_slave_exec: (module, method, params)->
    for i in [1...@options.server_all.length]
      @emit_server_exec(module, i, method, params)

  emit_server_circle_exec: (module, method, params)->
    @emit_server_exec(module, circle_server, method, params)
    circle_server = (circle_server + 1) % @options.server_all.length

  emit_server_other_exec: (module, method, params)->
    for i in [0...@options.server_all.length]
      if i isnt @options.server_id
        @emit_server_exec(module, i, method, params)

  emit_module_exec: (module, id, method, params)-> @emit "server:#{module}:exec:#{id}", {method, params}

  remove: (event)->
    @_event.removeAllListeners(event)
    @sub.unsubscribe(event)

  remove_module_exec: (module, id)-> @remove "server:#{module}:exec:#{id}"


module.exports.PubsubDev = class PubsubDev extends Pubsub
  on: (event)->
    console.info "--------on #{event} #{@options.server_id}"
    super

  emit: (event, params)->
    console.info "--------emit #{event} #{JSON.stringify(params)} #{@options.server_id}"
    super

  remove: (event)->
    console.info "--------remove #{event} #{@options.server_id}"
    super
