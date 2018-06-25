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
      server_id: 's1'
      server_name: 'm1'
      server_all: ['m2', 'm1', 'm3']
      redis: 'rd'
    })

  describe 'subscribe', ->
    it 'event', ->
      m.on 'event', spy
      assert.equal(1, sub.subscribe.callCount)

    it 'emit', ->
      m.on 'event', spy
      sub.on.getCall(0).args[1]('event', JSON.stringify({data: {id: 'test'}, server: 'b1'}))
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 'test'}, spy.getCall(0).args[0])
      assert.deepEqual('b1', spy.getCall(0).args[1])

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

    it 'on user', ->
      m.on = sinon.spy()
      m.on_user(5, 'call')
      assert.equal(1, m.on.callCount)
      assert.equal('room:user:5', m.on.getCall(0).args[0])
      assert.equal('call', m.on.getCall(0).args[1])

    it 'on user exec', ->
      m.on = sinon.spy()
      m.on_user_exec(5, 'call')
      assert.equal(1, m.on.callCount)
      assert.equal('room:user:exec:5', m.on.getCall(0).args[0])
      assert.equal('call', m.on.getCall(0).args[1])

    it 'on room exec', ->
      m.on = sinon.spy()
      m.on_room_exec(5, 'call')
      assert.equal(1, m.on.callCount)
      assert.equal('room:exec:5', m.on.getCall(0).args[0])
      assert.equal('call', m.on.getCall(0).args[1])

    it 'on users exec', ->
      m.on = sinon.spy()
      m.on_users_exec('call')
      assert.equal(1, m.on.callCount)
      assert.equal('room:users:exec', m.on.getCall(0).args[0])
      assert.equal('call', m.on.getCall(0).args[1])

    it 'on user (remove events)', ->
      m.remove = sinon.spy()
      m.remove_user(5)
      assert.equal(2, m.remove.callCount)
      assert.equal('room:user:5', m.remove.getCall(0).args[0])
      assert.equal('room:user:exec:5', m.remove.getCall(1).args[0])

    it 'on room (remove events)', ->
      m.remove = sinon.spy()
      m.remove_room(5)
      assert.equal(1, m.remove.callCount)
      assert.equal('room:exec:5', m.remove.getCall(0).args[0])

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


  describe 'emit', ->
    it 'publish', ->
      m.emit('event', {id: 'test'})
      assert.equal(1, pub.publish.callCount)
      assert.equal('event', pub.publish.getCall(0).args[0])
      assert.equal(JSON.stringify({data: {id: 'test'}, server: 's1'}), pub.publish.getCall(0).args[1])

    it 'publish callback', ->
      callback = sinon.spy()
      m.emit('event', {id: 'test'}, callback)
      pub.publish.getCall(0).args[2](null, 2)
      assert.equal(1, callback.callCount)
      assert.deepEqual([null, 2], callback.getCall(0).args)

    it 'publish user', ->
      m.emit = sinon.spy()
      m.emit_user(5, 'event', 'params', spy)
      assert.equal(1, m.emit.callCount)
      assert.equal('room:user:5', m.emit.getCall(0).args[0])
      assert.deepEqual({event: 'event', params: 'params'}, m.emit.getCall(0).args[1])
      m.emit.getCall(0).args[2]()
      assert.equal(1, spy.callCount)

    it 'publish user exec', ->
      m.emit = sinon.spy()
      m.emit_user_exec(5, 'method', 'params', spy)
      assert.equal(1, m.emit.callCount)
      assert.equal('room:user:exec:5', m.emit.getCall(0).args[0])
      assert.deepEqual({method: 'method', params: 'params'}, m.emit.getCall(0).args[1])
      m.emit.getCall(0).args[2]()
      assert.equal(1, spy.callCount)

    it 'publish room exec', ->
      m.emit = sinon.spy()
      m.emit_room_exec(5, 'method', 'params', spy)
      assert.equal(1, m.emit.callCount)
      assert.equal('room:exec:5', m.emit.getCall(0).args[0])
      assert.deepEqual({method: 'method', params: 'params'}, m.emit.getCall(0).args[1])
      m.emit.getCall(0).args[2]()
      assert.equal(1, spy.callCount)

    it 'publish users exec', ->
      m.emit = sinon.spy()
      m.emit_users_exec('method', 'params')
      assert.equal(1, m.emit.callCount)
      assert.equal('room:users:exec', m.emit.getCall(0).args[0])
      assert.deepEqual({method: 'method', params: 'params'}, m.emit.getCall(0).args[1])

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


  describe 'emit cases', ->
    beforeEach ->
      m.emit = sinon.spy()

    it 'user exec set (0 match)', ->
      s = sinon.spy()
      m.options.callback =
        set: s
      m.emit_user_exec(5, 'set', {coins: 15}, spy)
      m.emit.getCall(0).args[2](null, 0)
      assert.equal(1, s.callCount)
      assert.deepEqual({coins: 15, id: 5}, s.getCall(0).args[0])
      s.getCall(0).args[1]()
      assert.equal(1, spy.callCount)
      m.emit = sinon.spy()

    it 'user exec set_coins (other method)', ->
      s = sinon.spy()
      m.options.callback =
        set: s
      m.emit_user_exec(5, 'other_method', {coins: 5, type: 2}, spy)
      m.emit.getCall(0).args[2](null, 0)
      assert.equal(0, s.callCount)
      assert.equal(1, spy.callCount)
      assert.equal(1, spy.callCount)
