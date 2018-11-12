events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
SimpleEvent = require('simple.event').SimpleEvent


class Room extends SimpleEvent
  constructor: (attributes)->
    super()
    @attributes = attributes
  id: -> @attributes.id
  data_public: -> {id: @id()}

class User extends SimpleEvent


Rooms = proxyquire('../rooms', {
  '../../config':
    config_callback: (c)-> c
    module_get: -> {Room, User}
  './default':
    PubsubServerObjects: class PubsubServerObjects extends SimpleEvent
}).Rooms


describe 'Rooms', ->
  spy = null
  clock = null
  rooms = null
  beforeEach ->
    clock = sinon.useFakeTimers()
    spy = sinon.spy()
    rooms = new Rooms()

  afterEach ->
    clock.restore()

  describe 'default', ->
    it 'constructor', ->
      rooms = new Rooms()
      assert.equal('rooms', rooms._module)
      assert.deepEqual(Room, rooms.model())
      assert.deepEqual([], rooms._lobby)
      assert.deepEqual([], rooms._models)

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


  describe 'Lobby', ->
    emit_user = null
    beforeEach ->
      rooms.emit_user_exec = emit_user = sinon.spy()

    it '_lobby_index', ->
      rooms._lobby = [{id: 5}, {id: 6}]
      assert.equal(1, rooms._lobby_index(6))
      assert.equal(-1, rooms._lobby_index(10))

    it 'add', ->
      assert.deepEqual([], rooms._lobby)
      rooms.lobby_add({id: 5, bet: 6})
      assert.deepEqual([{id: 5, bet: 6}], rooms._lobby)
      assert.equal(1, emit_user.callCount)
      assert.equal(5, emit_user.getCall(0).args[0])
      assert.equal('_lobby_add',emit_user.getCall(0).args[1])
      assert.deepEqual({rooms: 'rooms', lobby: 1}, emit_user.getCall(0).args[2])

    it 'add (existing)', ->
      rooms._lobby_index = sinon.fake.returns(0)
      rooms.lobby_add({id: 5})
      assert.deepEqual([], rooms._lobby)
      assert.equal(5, rooms._lobby_index.getCall(0).args[0])
      assert.equal(0, emit_user.callCount)

    it 'remove', ->
      rooms._lobby = [{id: 6}, {id: 5}, {id: 7}]
      rooms._lobby_index = sinon.fake.returns(1)
      rooms.lobby_remove(5)
      assert.equal(1, rooms._lobby_index.callCount)
      assert.equal(5, rooms._lobby_index.getCall(0).args[0])
      assert.deepEqual([{id: 6}, {id: 7}], rooms._lobby)
      assert.equal(1, emit_user.callCount)
      assert.equal(5, emit_user.getCall(0).args[0])
      assert.equal('_lobby_remove',emit_user.getCall(0).args[1])
      assert.deepEqual({rooms: 'rooms'}, emit_user.getCall(0).args[2])

    it 'remove (unexisting)', ->
      rooms._lobby = [{id: 6}]
      rooms._lobby_index = sinon.fake.returns(-1)
      rooms.lobby_remove()
      assert.deepEqual([{id: 6}], rooms._lobby)
      assert.equal(0, emit_user.callCount)
