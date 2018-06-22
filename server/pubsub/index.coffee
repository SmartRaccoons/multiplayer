redis = require('redis')
EventEmitter = require('events').EventEmitter
Login = require('../room/authorize').Login

circle_server = 0

module.exports.Pubsub = class Pubsub
  constructor: (@options)->
    @pub = redis.createClient(@options.redis)
    @sub = redis.createClient(@options.redis)
    @_event = new EventEmitter()
    @sub.on 'message', (ch, message)=>
      m = JSON.parse(message)
      @_event.emit ch, m.data, m.server

  on: (event, fn)->
    @_event.on event, fn
    @sub.subscribe(event)

  on_all_exec: (module, callback)-> @on "server:#{module}:exec", callback

  on_server_exec: (module, callback)-> @on "server:#{module}:exec:#{@options.server_name}", callback

  on_user: (id, callback)-> @on "room:user:#{id}", callback

  on_user_exec: (id, callback)-> @on "room:user:exec:#{id}", callback

  on_room_exec: (id, callback)-> @on "room:exec:#{id}", callback

  on_users_exec: (callback)-> @on "room:users:exec", callback

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

  emit_user: (id, event, params, callback=->)-> @emit "room:user:#{id}", {event, params}, callback

  emit_user_exec: (id, method, params, callback=->)->
    @emit "room:user:exec:#{id}", {method, params}, (err, count)=>
      if not (count is 0 and @options.callback and method of @options.callback)
        return callback()
      @options.callback[method](Object.assign({id: id}, params), callback)

  emit_room_exec: (id, method, params, callback=->)-> @emit "room:exec:#{id}", {method, params}, callback

  emit_users_exec: (method, params, callback=->)-> @emit "room:users:exec", {method, params}, callback

  remove: (event)->
    @_event.removeAllListeners(event)
    @sub.unsubscribe(event)

  remove_user: (id)->
    @remove "room:user:#{id}"
    @remove "room:user:exec:#{id}"

  remove_room: (id)-> @remove "room:exec:#{id}"
