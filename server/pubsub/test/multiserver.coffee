assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


pubsub = {}
Multiserver = proxyquire('../multiserver', {
  '../../config':
    config_get: ()-> pubsub
})


class ModuleUser extends Multiserver.PubsubModule
  _module: 'user'

class ServerRooms extends Multiserver.PubsubServer
  _module: 'rooms'


describe 'Multiserver', ->
  spy = null
  beforeEach ->
    spy = sinon.spy()

  describe 'Module', ->
    m = null
    beforeEach ->
      pubsub.on_module_exec = sinon.spy()
      pubsub.remove_module_exec = sinon.spy()
      pubsub.emit_module_exec = sinon.spy()
      m = new ModuleUser({id: '5'})

    it 'constructor', ->
      assert.equal('5', m.id)
      assert.equal(1, pubsub.on_module_exec.callCount)
      assert.equal('user', pubsub.on_module_exec.getCall(0).args[0])
      assert.equal('5', pubsub.on_module_exec.getCall(0).args[1])

    it 'execute', ->
      m.public = sinon.spy()
      pubsub.on_module_exec.getCall(0).args[2]({method: 'public', params: 'pr'})
      assert.equal(1, m.public.callCount)
      assert.equal('pr', m.public.getCall(0).args[0])

    it 'emtpy', ->
      assert.throws -> new (Multiserver.PubsubModule)()

    it 'remove', ->
      m.remove()
      assert.equal(1, pubsub.remove_module_exec.callCount)
      assert.equal('user', pubsub.remove_module_exec.getCall(0).args[0])
      assert.equal('5', pubsub.remove_module_exec.getCall(0).args[1])

    it 'emit_module_exec', ->
      m.emit_module_exec('room', '4', 'me', 'pa')
      assert.equal(1, pubsub.emit_module_exec.callCount)
      assert.equal('room', pubsub.emit_module_exec.getCall(0).args[0])
      assert.equal('4', pubsub.emit_module_exec.getCall(0).args[1])
      assert.equal('me', pubsub.emit_module_exec.getCall(0).args[2])
      assert.equal('pa', pubsub.emit_module_exec.getCall(0).args[3])

    it 'emit_self_exec', ->
      m.emit_self_exec('4', 'me', 'pa')
      assert.equal(1, pubsub.emit_module_exec.callCount)
      assert.equal('user', pubsub.emit_module_exec.getCall(0).args[0])
      assert.equal('4', pubsub.emit_module_exec.getCall(0).args[1])
      assert.equal('me', pubsub.emit_module_exec.getCall(0).args[2])
      assert.equal('pa', pubsub.emit_module_exec.getCall(0).args[3])


  describe 'Server', ->
    m = null
    beforeEach ->
      pubsub.on_all_exec = sinon.spy()
      pubsub.on_server_exec = sinon.spy()
      pubsub.emit_all_exec = sinon.spy()
      pubsub.emit_server_exec = sinon.spy()
      pubsub.emit_server_master_exec = sinon.spy()
      pubsub.emit_server_slave_exec = sinon.spy()
      pubsub.emit_server_circle_exec = sinon.spy()
      pubsub.emit_server_other_exec = sinon.spy()
      m = new ServerRooms()

    it 'constructor', ->
      assert.equal(1, pubsub.on_all_exec.callCount)
      assert.equal(1, pubsub.on_server_exec.callCount)
      assert.equal('rooms', pubsub.on_all_exec.getCall(0).args[0])

    it 'execute', ->
      m.public = sinon.spy()
      pubsub.on_all_exec.getCall(0).args[1]({method: 'public', params: 'pr'})
      assert.equal(1, m.public.callCount)
      assert.equal('pr', m.public.getCall(0).args[0])
      pubsub.on_server_exec.getCall(0).args[1]({method: 'public', params: 'pr'})
      assert.equal(2, m.public.callCount)

    it 'emit_immediate_exec (with other)', ->
      m._method = sinon.spy()
      m.emit_server_other_exec = sinon.spy()
      m.emit_immediate_exec('_method', 'params')
      assert.equal(1, m.emit_server_other_exec.callCount)
      assert.equal('_method', m.emit_server_other_exec.getCall(0).args[0])
      assert.equal('params', m.emit_server_other_exec.getCall(0).args[1])
      assert.equal(1, m._method.callCount)
      assert.equal('params', m._method.getCall(0).args[0])
      assert.equal(true, m._method.getCall(0).args[2])

    it 'emit', ->
      m.emit_all_exec('arg')
      assert.equal(1, pubsub.emit_all_exec.callCount)
      assert.equal('rooms', pubsub.emit_all_exec.getCall(0).args[0])
      assert.equal('arg', pubsub.emit_all_exec.getCall(0).args[1])
      m.emit_server_exec()
      assert.equal(1, pubsub.emit_server_exec.callCount)
      m.emit_server_master_exec()
      assert.equal(1, pubsub.emit_server_master_exec.callCount)
      m.emit_server_slave_exec()
      assert.equal(1, pubsub.emit_server_slave_exec.callCount)
      m.emit_server_circle_exec()
      assert.equal(1, pubsub.emit_server_circle_exec.callCount)
      m.emit_server_other_exec()
      assert.equal(1, pubsub.emit_server_other_exec.callCount)
