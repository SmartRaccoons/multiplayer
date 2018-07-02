events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


PubsubModule_methods =
  constructor: ->
  remove: ->

class User

Room = proxyquire('../room', {
  '../../config':
    config_callback: (c)-> c()
    module_get: ->
      {User}
    config_get: -> 5
  '../pubsub/multiserver':
    PubsubModule: class PubsubModule
      constructor: -> PubsubModule_methods.constructor.apply(@, arguments)
      remove: -> PubsubModule_methods.remove.apply(@, arguments)
}).Room


RoomGame_methods =
  constructor: ->
class RoomGame extends Room
  game: class Game
    constructor: -> RoomGame_methods.constructor.apply(@, arguments)
  game_methods:
    move: {}
    fold: {waiting: false}



describe 'Room', ->
  spy = null
  clock = null
  room = null
  beforeEach ->
    clock = sinon.useFakeTimers()
    spy = sinon.spy()
    PubsubModule_methods.constructor = sinon.spy()
    PubsubModule_methods.remove = sinon.spy()
    room = new RoomGame({users: [], type: 'sng'})
    room.users = [{id: 5}, {id: 6}]

  afterEach ->
    clock.restore()

  describe 'Room default', ->

    it 'id', ->
      assert.equal('5:1', room.id())
      assert.equal('5:2', (new Room({})).id())

    it 'pubsub ', ->
      assert.equal('room', room._module)
      assert.equal(1, PubsubModule_methods.constructor.callCount)
      room.remove()
      assert.equal(1, PubsubModule_methods.remove.callCount)

    it 'with attributes', ->
      class R extends RoomGame
        user_add: -> spy.apply(@, arguments)
      new R({users: [{id: 2}, {id: 3}]})
      assert.equal(2, spy.callCount)
      assert.deepEqual({id: 2}, spy.getCall(0).args[0])
      assert.deepEqual({id: 3}, spy.getCall(1).args[0])

    it 'user_add', ->
      room.users = []
      room.user_add({id: 5})
      assert.deepEqual([{id: 5}], room.users)

    it 'user_get', ->
      assert.equal(5, room.user_get(5).id)
      assert.equal(0, room.user_get(5, true))
      assert.equal(undefined, room.user_get(10))

    it 'user_remove', ->
      room.user_remove(6)
      assert.deepEqual([{id: 5}], room.users)

    it 'emit_user_publish', ->
      User::emit_self_publish = spy = sinon.spy()
      room.emit_user_publish(5, 'ev', 'pr')
      assert.equal(1, spy.callCount)
      assert.equal(5, spy.getCall(0).args[0])
      assert.equal('ev', spy.getCall(0).args[1])
      assert.equal('pr', spy.getCall(0).args[2])

    it 'emit_users_publish', ->
      room.emit_user_publish = spy = sinon.spy()
      room.emit_users_publish('ev', 'pr')
      assert.equal(2, spy.callCount)
      assert.equal(5, spy.getCall(0).args[0])
      assert.equal('ev', spy.getCall(0).args[1])
      assert.equal('pr', spy.getCall(0).args[2])
      assert.equal(6, spy.getCall(1).args[0])


  describe 'Game', ->
    beforeEach ->
      RoomGame_methods.constructor = sinon.spy()
      room._game_start()
      room._game.waiting = -> 5
      room._game.move = spy = sinon.spy()

    it 'no class throw', ->
      room = new Room({})
      assert.throws -> room._game_start()

    it 'pass attributes', ->
      RoomGame_methods.constructor = sinon.spy()
      room._game_start()
      assert.equal(1, RoomGame_methods.constructor.callCount)
      assert.deepEqual({users: [5, 6], type: 'sng'}, RoomGame_methods.constructor.getCall(0).args[0])

    it '_game_exec', ->
      room._game_exec({user_id: 5, method: 'move', params: {p: 'pr'}})
      assert.equal(1, spy.callCount)
      assert.deepEqual({p: 'pr', user_id: 5}, spy.getCall(0).args[0])

    it '_game_exec (no game)', ->
      delete room._game
      room._game_exec({user_id: 5, method: 'move', params: {p: 'pr'}})

    it '_game_exec (waiting)', ->
      room._game.fold = sinon.spy()
      room._game_exec({user_id: 6, method: 'move', params: {p: 'pr'}})
      assert.equal(0, spy.callCount)
      room._game_exec({user_id: 6, method: 'fold', params: {p: 'pr'}})
      assert.equal(1, room._game.fold.callCount)

    it '_game_exec (no method)', ->
      room._game.ben = spy = sinon.spy()
      room._game_exec({user_id: 5, method: 'ben', params: {p: 'pr'}})
      assert.equal(0, spy.callCount)

    it '_game_exec (no user)', ->
      room._game_exec({user_id: 15, method: 'move', params: {p: 'pr'}})
      assert.equal(0, spy.callCount)
