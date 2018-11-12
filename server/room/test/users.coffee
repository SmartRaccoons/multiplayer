events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
SimpleEvent = require('simple.event').SimpleEvent


class User extends SimpleEvent
  constructor: (attributes)->
    super()
    @attributes = attributes
  id: -> @attributes.id
  data_public: -> {p: 'public'}


PubsubServer_methods =
  _add: ->
  _create: ->

Users = proxyquire('../users', {
  '../../config':
    config_callback: (c)-> c
    module_get: -> {User}
  './default':
    PubsubServerObjects: class PubsubServerObjects extends SimpleEvent
      _add: -> PubsubServer_methods._add.apply(@, arguments)
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
      assert.equal('users', users._module)
      assert.deepEqual(User, users.model())

    it '_add', ->
      users._check_duplicate = sinon.spy()
      users._add({id: 2}, '', true)
      assert.equal(0, users._check_duplicate.callCount)
      assert.equal(1, PubsubServer_methods._add.callCount)

    it '_add (other)', ->
      users._check_duplicate = sinon.spy()
      users._add({id: 2}, '', false)
      assert.equal(1, users._check_duplicate.callCount)
      assert.equal(2, users._check_duplicate.getCall(0).args[0])

    it '_create', ->
      users._check_duplicate = sinon.spy()
      user = users._create({id: 5})
      assert.equal(1, users._check_duplicate.callCount)
      assert.equal(5, users._check_duplicate.getCall(0).args[0])
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
