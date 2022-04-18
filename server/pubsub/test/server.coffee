assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


redis = {}
Pubsub = proxyquire('../server', {
  'redis': redis
}).Pubsub


describe 'Pubsub', ->
  spy = null
  m = null
  sub = null
  pub = null
  module_server = null
  module_id = null
  beforeEach ->
    a = 0
    redis.createClient = sinon.fake ->
      a++
      if a is 1
        pub =
          publish: sinon.spy()
        return pub
      sub =
        subscribe: sinon.spy()
        unsubscribe: sinon.spy()
        on: sinon.spy()
      return sub
    spy = sinon.spy()
    m =  new Pubsub({
      server_id: 1
      server_all: ['m2', 'm1', 'm3']
      redis: 'rd'
    })
    module_server = {_module: (-> 'room'), on_to: sinon.spy()}
    module_id = {_module: (-> 'ro'), id: 'i1', on_to: sinon.spy()}


  it '_events', ->
    assert.equal 'server:mo:exec', m._events.all_exec('mo')
    assert.equal 'server:mo:exec:m1', m._events.server_exec.bind(m)('mo', 1)
    assert.equal 'servermodule:mo:exec:1', m._events.module_exec('mo', 1)

  it 'constructor', ->
    assert.equal(2, redis.createClient.callCount)
    assert.equal('rd', redis.createClient.getCall(0).args[0])
    assert.equal('rd', redis.createClient.getCall(1).args[0])

  it 'constructor (message)', ->
    assert.equal(1, sub.on.callCount)
    assert.equal('message', sub.on.getCall(0).args[0])
    m._events_holder.emit = sinon.spy()
    sub.on.getCall(0).args[1]('event', JSON.stringify({data: 'd', server: 1}))
    assert.equal 1, m._events_holder.emit.callCount
    assert.equal 'event', m._events_holder.emit.getCall(0).args[0]
    assert.equal 'd', m._events_holder.emit.getCall(0).args[1]
    assert.equal 1, m._events_holder.emit.getCall(0).args[2]
    assert.equal true, m._events_holder.emit.getCall(0).args[3]

  it 'constructor (message stringify Date)', ->
    m._events_holder.emit = sinon.spy()
    sub.on.getCall(0).args[1]('event', JSON.stringify({data: {da: new Date()}, server: 1}))
    assert.ok m._events_holder.emit.getCall(0).args[1].da instanceof Date

  it 'constructor (message server other)', ->
    m._events_holder.emit = sinon.spy()
    sub.on.getCall(0).args[1]('event', JSON.stringify({data: 'd', server: 2}))
    assert.equal false, m._events_holder.emit.getCall(0).args[3]

  it 'on', ->
    m._events_holder.on = sinon.spy()
    m.sub.subscribe = sinon.spy()
    m.on 'ev', 'fn'
    assert.equal(1, m._events_holder.on.callCount)
    assert.equal('ev', m._events_holder.on.getCall(0).args[0])
    assert.equal('fn', m._events_holder.on.getCall(0).args[1])
    assert.equal(1, m.sub.subscribe.callCount)
    assert.equal('ev', m.sub.subscribe.getCall(0).args[0])

  it 'emit', ->
    m.pub.publish = sinon.spy()
    m.emit 'ev', 'd', 'c'
    assert.equal(1, m.pub.publish.callCount)
    assert.equal('ev', m.pub.publish.getCall(0).args[0])
    assert.deepEqual({data: 'd', server: 1}, JSON.parse(m.pub.publish.getCall(0).args[1]))
    assert.equal('c', m.pub.publish.getCall(0).args[2])

  it 'on_server_exec', ->
    module_server['pip'] = sinon.spy()
    m.on = sinon.spy()
    m.on_server_exec(module_server)
    assert.equal 1, module_server.on_to.callCount
    assert.deepEqual m, module_server.on_to.getCall(0).args[0]
    assert.equal 'server:room:exec:m1', module_server.on_to.getCall(0).args[1]
    module_server.on_to.getCall(0).args[2]({method: 'pip', params: ['prm1', 'prm2']})
    assert.equal(1, module_server['pip'].callCount)
    assert.equal('prm1', module_server['pip'].getCall(0).args[0])
    assert.equal('prm2', module_server['pip'].getCall(0).args[1])

  it 'on_module_exec', ->
    m.on = sinon.spy()
    m.on_module_exec(module_id)
    assert.equal('servermodule:ro:exec:i1', module_id.on_to.getCall(0).args[1])

  it 'emit_server_exec', ->
    m.emit = sinon.spy()
    callback = ->
    m.emit_server_exec('mod', 2, 'mth', 'prm', 'prm2', callback)
    assert.equal('server:mod:exec:m3', m.emit.getCall(0).args[0])
    assert.deepEqual({method: 'mth', params: ['prm', 'prm2']}, m.emit.getCall(0).args[1])
    assert.deepEqual(callback, m.emit.getCall(0).args[2])

  it 'emit_module_exec', ->
    m.emit = sinon.spy()
    m.emit_module_exec('mod', 'id', 'mth', 'prm', 'prm2')
    assert.equal('servermodule:mod:exec:id', m.emit.getCall(0).args[0])
    assert.deepEqual({method: 'mth', params: ['prm', 'prm2']}, m.emit.getCall(0).args[1])

  it 'off', ->
    m._events_holder.off = sinon.spy()
    m._events_holder._events = {}
    m.sub.unsubscribe = sinon.spy()
    m.off 'event'
    assert.equal 1, m._events_holder.off.callCount
    assert.equal 'event', m._events_holder.off.getCall(0).args[0]
    assert.equal 1, m.sub.unsubscribe.callCount
    assert.equal 'event', m.sub.unsubscribe.getCall(0).args[0]

  it 'off (exists events)', ->
    m._events_holder.off = sinon.spy()
    m._events_holder._events = {'event': [(->)]}
    m.sub.unsubscribe = sinon.spy()
    m.off 'event'
    assert.equal 0, m.sub.unsubscribe.callCount

  it 'emit_server_master_exec', ->
    m.emit_server_exec = emit = sinon.spy()
    m.emit_server_master_exec('module', 'method', 'params', 'params2')
    assert.equal(1, emit.callCount)
    assert.equal('module', emit.getCall(0).args[0])
    assert.equal(0, emit.getCall(0).args[1])
    assert.equal('method', emit.getCall(0).args[2])
    assert.equal('params', emit.getCall(0).args[3])
    assert.equal('params2', emit.getCall(0).args[4])

  it 'emit_server_slave_exec', ->
    m.emit_server_exec = emit = sinon.spy()
    m.emit_server_slave_exec('module', 'method', 'params', 'params2')
    assert.equal(2, emit.callCount)
    assert.equal('module', emit.getCall(0).args[0])
    assert.equal(1, emit.getCall(0).args[1])
    assert.equal(2, emit.getCall(1).args[1])
    assert.equal('method', emit.getCall(0).args[2])
    assert.equal('params', emit.getCall(0).args[3])
    assert.equal('params2', emit.getCall(0).args[4])

  it 'emit_server_circle_exec', ->
    m.emit_server_exec = emit = sinon.spy()
    m.emit_server_circle_exec('module', 'method', 'params', 'params2')
    assert.equal(1, emit.callCount)
    assert.equal('module', emit.getCall(0).args[0])
    assert.equal(0, emit.getCall(0).args[1])
    assert.equal('method', emit.getCall(0).args[2])
    assert.equal('params', emit.getCall(0).args[3])
    assert.equal('params2', emit.getCall(0).args[4])
    m.emit_server_circle_exec('module', 'method', 'params')
    assert.equal(2, emit.callCount)
    assert.equal(1, emit.getCall(1).args[1])
    m.emit_server_circle_exec('module', 'method', 'params')
    assert.equal(3, emit.callCount)
    assert.equal(2, emit.getCall(2).args[1])
    m.emit_server_circle_exec('module', 'method', 'params')
    assert.equal(4, emit.callCount)
    assert.equal(0, emit.getCall(3).args[1])

  it 'emit_server_circle_slave_exec', ->
    m.emit_server_exec = emit = sinon.spy()
    m.emit_server_circle_slave_exec('module', 'method', 'params')
    assert.equal(1, emit.callCount)
    assert.equal('module', emit.getCall(0).args[0])
    assert.equal(1, emit.getCall(0).args[1])
    assert.equal('method', emit.getCall(0).args[2])
    assert.equal('params', emit.getCall(0).args[3])
    m.emit_server_circle_slave_exec('module', 'method', 'params')
    assert.equal(2, emit.callCount)
    assert.equal(2, emit.getCall(1).args[1])
    m.emit_server_circle_slave_exec('module', 'method', 'params')
    assert.equal(1, emit.getCall(2).args[1])

  it 'emit_server_circle_slave_exec (only one)', ->
    m.options.server_all = ['m1']
    m.emit_server_exec = emit = sinon.spy()
    m.emit_server_circle_slave_exec('module', 'method', 'params')
    assert.equal(0, emit.getCall(0).args[1])

  it 'emit_server_other_exec', ->
    m.emit_server_exec = emit = sinon.spy()
    m.emit_server_other_exec('module', 'method', 'params', 'params2')
    assert.equal(2, emit.callCount)
    assert.equal('module', emit.getCall(0).args[0])
    assert.equal(0, emit.getCall(0).args[1])
    assert.equal(2, emit.getCall(1).args[1])
    assert.equal('method', emit.getCall(0).args[2])
    assert.equal('params', emit.getCall(0).args[3])
    assert.equal('params2', emit.getCall(0).args[4])
