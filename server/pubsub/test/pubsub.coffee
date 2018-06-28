assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


redis = {}
Pubsub = proxyquire('../', {
  'redis': redis
}).Pubsub


describe 'Pubsub', ->
  spy = null
  m = null
  sub = null
  pub = null
  beforeEach ->
    a = 0
    redis.createClient = ->
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

  describe 'subscribe', ->
    it 'event', ->
      m.on 'event', spy
      assert.equal(1, sub.subscribe.callCount)

    it 'emit', ->
      m.on 'event', spy
      sub.on.getCall(0).args[1]('event', JSON.stringify({data: {id: 'test'}, server: 5}))
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 'test'}, spy.getCall(0).args[0])
      assert.equal(5, spy.getCall(0).args[1])
      assert.equal(false, spy.getCall(0).args[2])

    it 'emit (same server)', ->
      m.on 'event', spy
      sub.on.getCall(0).args[1]('event', JSON.stringify({data: {id: 'test'}, server: 1}))
      assert.equal(true, spy.getCall(0).args[2])

    it 'unsubscribe', ->
      m.on 'event', spy
      m.remove 'event'
      assert.equal(1, sub.unsubscribe.callCount)
      sub.on.getCall(0).args[1]('event', JSON.stringify({data: {id: 'test'}}))
      assert.equal(0, spy.callCount)

    it 'resubscribe', ->
      m.on 'event', spy
      m.remove 'event'
      m.on 'event', spy
      sub.on.getCall(0).args[1]('event', JSON.stringify({data: {id: 'test'}}))
      assert.equal(1, spy.callCount)

    it 'on server', ->
      m.on = sinon.spy()
      m.on_server_exec('module', 'call')
      assert.equal(1, m.on.callCount)
      assert.equal('server:module:exec:m1', m.on.getCall(0).args[0])
      assert.equal('call', m.on.getCall(0).args[1])

    it 'on all', ->
      m.on = sinon.spy()
      m.on_all_exec('module', 'call')
      assert.equal(1, m.on.callCount)
      assert.equal('server:module:exec', m.on.getCall(0).args[0])
      assert.equal('call', m.on.getCall(0).args[1])

    it 'on_module_exec', ->
      m.on = sinon.spy()
      m.on_module_exec('module', 'id', 'call')
      assert.equal(1, m.on.callCount)
      assert.equal('server:module:exec:id', m.on.getCall(0).args[0])
      assert.equal('call', m.on.getCall(0).args[1])

    it 'remove_module_exec', ->
      m.remove = sinon.spy()
      m.remove_module_exec('module', 'id')
      assert.equal(1, m.remove.callCount)
      assert.equal('server:module:exec:id', m.remove.getCall(0).args[0])


  describe 'emit', ->
    it 'publish', ->
      m.emit('event', {id: 'test'})
      assert.equal(1, pub.publish.callCount)
      assert.equal('event', pub.publish.getCall(0).args[0])
      assert.equal(JSON.stringify({data: {id: 'test'}, server: 1}), pub.publish.getCall(0).args[1])

    it 'publish callback', ->
      callback = sinon.spy()
      m.emit('event', {id: 'test'}, callback)
      pub.publish.getCall(0).args[2](null, 2)
      assert.equal(1, callback.callCount)
      assert.deepEqual([null, 2], callback.getCall(0).args)

    it 'publish all', ->
      m.emit = sinon.spy()
      m.emit_all_exec('module', 'method', 'params')
      assert.equal(1, m.emit.callCount)
      assert.equal('server:module:exec', m.emit.getCall(0).args[0])
      assert.deepEqual({method: 'method', params: 'params'}, m.emit.getCall(0).args[1])

    it 'publish server exec', ->
      m.emit = sinon.spy()
      m.emit_server_exec('module', 1, 'method', 'params')
      assert.equal(1, m.emit.callCount)
      assert.equal('server:module:exec:m1', m.emit.getCall(0).args[0])
      assert.deepEqual({method: 'method', params: 'params'}, m.emit.getCall(0).args[1])

    it 'publish server master exec', ->
      m.emit_server_exec = emit = sinon.spy()
      m.emit_server_master_exec('module', 'method', 'params')
      assert.equal(1, emit.callCount)
      assert.equal('module', emit.getCall(0).args[0])
      assert.equal(0, emit.getCall(0).args[1])
      assert.equal('method', emit.getCall(0).args[2])
      assert.equal('params', emit.getCall(0).args[3])

    it 'publish server slave exec', ->
      m.emit_server_exec = emit = sinon.spy()
      m.emit_server_slave_exec('module', 'method', 'params')
      assert.equal(2, emit.callCount)
      assert.equal('module', emit.getCall(0).args[0])
      assert.equal(1, emit.getCall(0).args[1])
      assert.equal(2, emit.getCall(1).args[1])
      assert.equal('method', emit.getCall(0).args[2])
      assert.equal('params', emit.getCall(0).args[3])

    it 'publish server circle exec', ->
      m.emit_server_exec = emit = sinon.spy()
      m.emit_server_circle_exec('module', 'method', 'params')
      assert.equal(1, emit.callCount)
      assert.equal('module', emit.getCall(0).args[0])
      assert.equal(0, emit.getCall(0).args[1])
      assert.equal('method', emit.getCall(0).args[2])
      assert.equal('params', emit.getCall(0).args[3])
      m.emit_server_circle_exec('module', 'method', 'params')
      assert.equal(2, emit.callCount)
      assert.equal(1, emit.getCall(1).args[1])
      m.emit_server_circle_exec('module', 'method', 'params')
      assert.equal(3, emit.callCount)
      assert.equal(2, emit.getCall(2).args[1])
      m.emit_server_circle_exec('module', 'method', 'params')
      assert.equal(4, emit.callCount)
      assert.equal(0, emit.getCall(3).args[1])

    it 'publish server other exec', ->
      m.emit_server_exec = emit = sinon.spy()
      m.emit_server_other_exec('module', 'method', 'params')
      assert.equal(2, emit.callCount)
      assert.equal('module', emit.getCall(0).args[0])
      assert.equal(0, emit.getCall(0).args[1])
      assert.equal(2, emit.getCall(1).args[1])
      assert.equal('method', emit.getCall(0).args[2])
      assert.equal('params', emit.getCall(0).args[3])

    it 'emit_module_exec', ->
      m.emit = sinon.spy()
      m.emit_module_exec('module', 'id', 'method', 'params')
      assert.equal(1, m.emit.callCount)
      assert.equal('server:module:exec:id', m.emit.getCall(0).args[0])
      assert.deepEqual({method: 'method', params: 'params'}, m.emit.getCall(0).args[1])
