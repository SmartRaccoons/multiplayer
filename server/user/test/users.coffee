events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
SimpleEvent = require('simple.event').SimpleEvent


class User extends SimpleEvent
  constructor: (options)->
    super()
    @options = options
  id: -> @options.id
  data_public: -> {p: 'public'}


PubsubServer_methods =
  _create: ->

Users = proxyquire('../users', {
  '../../config':
    config_callback: (c)-> c
    module_get: -> {User}
  '../pubsub/objects':
    PubsubServerObjects: class PubsubServerObjects extends SimpleEvent
      _create: -> PubsubServer_methods._create.apply(@, arguments)
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
      PubsubServer_methods._add = sinon.spy()
      PubsubServer_methods._create = sinon.spy()
      users = new Users()
      users.emit_immediate_exec = sinon.spy()

    it 'constructor', ->
      users = new Users()
      assert.deepEqual(User, users.model())

    it '_create', ->
      users._check_duplicate = sinon.spy()
      users.emit_immediate_exec = sinon.spy()
      user = users._create({id: 5})
      assert.equal(1, users.emit_immediate_exec.callCount)
      assert.equal('_check_duplicate', users.emit_immediate_exec.getCall(0).args[0])
      assert.equal(5, users.emit_immediate_exec.getCall(0).args[1])
      assert.equal(1, PubsubServer_methods._create.callCount)

    it '_check_duplicate', ->
      user = new User({id: 5})
      user.remove = sinon.spy()
      users.get = -> user
      users._check_duplicate(5)
      assert.equal(1, user.remove.callCount)
      assert.equal('duplicate', user.remove.getCall(0).args[0])

    it '_check_duplicate (no model)', ->
      users.get = -> false
      users._check_duplicate(555)

    it 'publish_menu', ->
      user1 = new User({id: 4})
      user2 = new User({id: 3})
      user1.room = 'some room'
      user1.publish = spy
      user2.publish = spy2
      users._objects = [user1, user2]
      users.publish_menu('event', 'params')
      assert.equal(0, spy.callCount)
      assert.equal(1, spy2.callCount)
      assert.equal('event', spy2.getCall(0).args[0])
      assert.equal('params', spy2.getCall(0).args[1])
