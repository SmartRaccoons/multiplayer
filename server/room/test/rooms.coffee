events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
SimpleEvent = require('simple.event').SimpleEvent


class Room extends SimpleEvent
  constructor: (options)->
    super()
    @options = options
  id: -> @options.id
  data_public: -> {id: @id()}

class User extends SimpleEvent


config_callbacks = []
{Rooms, RoomsLobby} = proxyquire('../rooms', {
  '../../config':
    config_callback: (c)->
      config_callbacks.push c
    module_get: -> {Room, User}
  '../pubsub/objects':
    PubsubServerObjects: class PubsubServerObjects extends SimpleEvent
})


describe 'Rooms', ->
  spy = null
  clock = null
  rooms = null
  beforeEach ->
    clock = sinon.useFakeTimers()
    spy = sinon.spy()
    config_callbacks[0]()
    rooms = new Rooms()

  afterEach ->
    clock.restore()

  describe 'default', ->
    it 'constructor', ->
      rooms = new Rooms()
      assert.deepEqual(Room, rooms.model())

    it 'default', ->
      assert.deepEqual([], rooms._lobby)

    it 'emit_user_exec', ->
      User::emit_self_exec = emit_user = sinon.spy()
      rooms.emit_user_exec(1, 'm', 'p')
      assert.equal(1, emit_user.callCount)
      assert.equal(1, emit_user.getCall(0).args[0])
      assert.equal('m', emit_user.getCall(0).args[1])
      assert.equal('p', emit_user.getCall(0).args[2])

    it 'emit_user_publish', ->
      User::emit_self_publish = emit_user = sinon.spy()
      rooms.emit_user_publish(1, 'm', 'p')
      assert.equal(1, emit_user.callCount)
      assert.equal(1, emit_user.getCall(0).args[0])
      assert.equal('m', emit_user.getCall(0).args[1])
      assert.equal('p', emit_user.getCall(0).args[2])

    it '_lobby_index', ->
      rooms._lobby = [{id: 5}, {id: 6}]
      assert.equal(1, rooms._lobby_index(6))
      assert.equal(-1, rooms._lobby_index(10))

    it '_lobby_check', ->
      rooms._lobby_index = sinon.fake.returns 0
      assert.equal false, rooms._lobby_check({id: 5})
      assert.equal 1, rooms._lobby_index.callCount
      assert.equal 5, rooms._lobby_index.getCall(0).args[0]

    it '_lobby_check (false)', ->
      rooms._lobby_index = sinon.fake.returns -1
      assert.equal true, rooms._lobby_check({id: 5})

    it '_lobby_params', ->
      rooms._module = -> 'mod'
      assert.deepEqual {module: 'mod'}, rooms._lobby_params()

    it 'add', ->
      rooms._lobby_params = sinon.fake.returns 'p'
      rooms._lobby_check = sinon.fake.returns true
      rooms.emit_user_exec = sinon.spy()
      assert.deepEqual([], rooms._lobby)
      assert.equal true, rooms.lobby_add({id: 5, bet: 6})
      assert.deepEqual([{id: 5, bet: 6}], rooms._lobby)
      assert.equal 1, rooms._lobby_check.callCount
      assert.deepEqual {id: 5, bet: 6}, rooms._lobby_check.getCall(0).args[0]
      assert.equal 1, rooms._lobby_params.callCount
      assert.deepEqual {id: 5, bet: 6}, rooms._lobby_params.getCall(0).args[0]
      assert.equal 1, rooms.emit_user_exec.callCount
      assert.equal 5, rooms.emit_user_exec.getCall(0).args[0]
      assert.equal '_lobby_add', rooms.emit_user_exec.getCall(0).args[1]
      assert.equal 'p', rooms.emit_user_exec.getCall(0).args[2]

    it 'add (existing)', ->
      rooms.emit_user_exec = sinon.spy()
      rooms._lobby_check = sinon.fake.returns false
      assert.equal false, rooms.lobby_add({id: 5})
      assert.deepEqual([], rooms._lobby)
      assert.equal 0, rooms.emit_user_exec.callCount


    describe 'lobby_remove', ->
      beforeEach ->
        rooms.emit_user_exec = sinon.spy()
        rooms._lobby_params = sinon.fake.returns 'p'
        rooms._lobby = [{id: 6}, {id: 5, room_id: 2}, {id: 7}]
        rooms._lobby_index = sinon.fake.returns(1)

      it 'default', ->
        assert.deepEqual {id: 5, room_id: 2}, rooms.lobby_remove({id: 5})
        assert.equal(1, rooms._lobby_index.callCount)
        assert.equal(5, rooms._lobby_index.getCall(0).args[0])
        assert.deepEqual([{id: 6}, {id: 7}], rooms._lobby)
        assert.equal 1, rooms._lobby_params.callCount
        assert.deepEqual {id: 5, room_id: 2}, rooms._lobby_params.getCall(0).args[0]
        assert.equal 1, rooms.emit_user_exec.callCount
        assert.equal 5, rooms.emit_user_exec.getCall(0).args[0]
        assert.equal '_lobby_remove', rooms.emit_user_exec.getCall(0).args[1]
        assert.equal 'p', rooms.emit_user_exec.getCall(0).args[2]

      it 'remove', ->
        rooms.lobby_remove({id: 5}, {silent: true})
        assert.equal 0, rooms.emit_user_exec.callCount

      it 'unexisting', ->
        rooms._lobby_index = sinon.fake.returns(-1)
        assert.equal false, rooms.lobby_remove({id: 1000})
        assert.equal 0, rooms.emit_user_exec.callCount
