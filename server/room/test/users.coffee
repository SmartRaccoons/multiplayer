events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
SimpleEvent = require('simple.event').SimpleEvent


class User extends SimpleEvent
  constructor: (@attributes)->
  id: -> @attributes.id
  data_public: -> {p: 'public'}


PubsubServer_methods =
  constructor: ->

Users = proxyquire('../users', {
  '../../config':
    config_callback: (c)-> c
    module_get: -> {User}
  '../pubsub/multiserver':
    PubsubServer: class PubsubServer extends SimpleEvent
      constructor: -> PubsubServer_methods.constructor.apply(@, arguments)
}).Users


describe 'Users', ->
  spy = null
  spy2 = null
  clock = null
  beforeEach ->
    clock = sinon.useFakeTimers()
    spy = sinon.spy()
    spy2 = sinon.spy()

  afterEach ->
    clock.restore()

  describe 'Users', ->
    users = null
    beforeEach ->
      PubsubServer_methods.constructor = sinon.spy()
      users = new Users()
      users.emit_immediate_exec = sinon.spy()

    it 'constructor', ->
      PubsubServer_methods.constructor = sinon.spy()
      users = new Users()
      assert.equal('users', users._module)
      assert.equal(1, PubsubServer_methods.constructor.callCount)

    it 'get', ->
      users._objects = [{id: -> 2}, {id: -> 4}, {id: -> 1}]
      assert.equal(4, users.get(4).id())
      assert.equal(1, users.get(4, true))

    it '_add', ->
      users._check_duplicate = sinon.spy()
      users.bind 'add', spy
      users._add({id: 2}, '', true)
      assert.deepEqual([{id: 2}], users._all)
      assert.equal(0, users._check_duplicate.callCount)
      assert.equal(1, spy.callCount)

    it '_add (other)', ->
      users._check_duplicate = sinon.spy()
      users._add({id: 2}, '', false)
      assert.equal(1, users._check_duplicate.callCount)
      assert.equal(2, users._check_duplicate.getCall(0).args[0])

    it '_remove', ->
      users.bind 'remove', spy
      users._add({id: 1})
      users._add({id: 2})
      users._add({id: 3})
      users._remove(2)
      assert.deepEqual([{id: 1}, {id: 3}], users._all)
      assert.equal(1, spy.callCount)

    it 'add_native', ->
      user = users.add_native({id: 5})
      assert.equal(5, user.attributes.id)
      assert.equal(1, users.emit_immediate_exec.callCount)
      assert.equal('_add', users.emit_immediate_exec.getCall(0).args[0])
      assert.deepEqual({p: 'public'}, users.emit_immediate_exec.getCall(0).args[1])
      assert.deepEqual([user], users._objects)

    it 'add_native (_check_duplicate)', ->
      users._check_duplicate = sinon.spy()
      user = users.add_native({id: 5})
      assert.equal(1, users._check_duplicate.callCount)
      assert.equal(5, users._check_duplicate.getCall(0).args[0])

    it 'add_native (remove)', ->
      user = users.add_native({id: 5})
      user2 = users.add_native({id: 6})
      user3 = users.add_native({id: 7})
      users.emit_immediate_exec = sinon.spy()
      user2.remove()
      assert.deepEqual([user, user3], users._objects)
      assert.equal(1, users.emit_immediate_exec.callCount)
      assert.equal('_remove', users.emit_immediate_exec.getCall(0).args[0])
      assert.equal(6, users.emit_immediate_exec.getCall(0).args[1])

    it '_check_duplicate', ->
      user = users.add_native({id: 5})
      user.attributes.socket = socket =
        disconnect: sinon.spy()
      users._check_duplicate(5)
      assert.equal(1, socket.disconnect.callCount)
      assert.equal('duplicate', socket.disconnect.getCall(0).args[0])

    it '_check_duplicate (no model)', ->
      users._check_duplicate(555)

    it 'publish_menu', ->
      user1 = users.add_native({id: 4})
      user2 = users.add_native({id: 3})
      user1.room = 'some room'
      user1.publish = spy
      user2.publish = spy2
      users.publish_menu('event', 'params')
      assert.equal(0, spy.callCount)
      assert.equal(1, spy2.callCount)
      assert.equal('event', spy2.getCall(0).args[0])
      assert.equal('params', spy2.getCall(0).args[1])
