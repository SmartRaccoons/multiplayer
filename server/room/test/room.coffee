events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
SimpleEvent = require('simple.event').SimpleEvent


PubsubModule_methods =
  constructor: ->
  remove: ->

class User

Room = proxyquire('../room', {
  '../../config':
    config_callback: (c)->
      c()
      c
    module_get: ->
      {User}
    config_get: -> 5
  '../pubsub/multiserver':
    PubsubModule: class PubsubModule extends SimpleEvent
      _module: -> @.constructor.name
      constructor: ->
        super ...arguments
        PubsubModule_methods.constructor.apply(@, arguments)
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
    room.spectators = [{id: 3}, {id: 4}]

  afterEach ->
    clock.restore()

  describe 'Room default', ->

    it 'pubsub ', ->
      room.users = []
      room.spectators = []
      assert.equal(1, PubsubModule_methods.constructor.callCount)
      assert.deepEqual({id: '5:1'}, PubsubModule_methods.constructor.getCall(0).args[0])
      room.remove()
      assert.equal(1, PubsubModule_methods.remove.callCount)

    it 'pubsub (auto id)', ->
      assert.deepEqual({id: '5:2'}, PubsubModule_methods.constructor.getCall(0).args[0])
      new RoomGame({id: '2'})
      assert.deepEqual({id: '2'}, PubsubModule_methods.constructor.getCall(1).args[0])

    it 'data_public', ->
      room.id = '5'
      assert.deepEqual({id: '5', users: [{id: 5}, {id: 6}], spectators: [{id: 3}, {id: 4}]}, room.data_public())

    it 'remove', ->
      room.user_remove = sinon.spy()
      room.remove()
      assert.equal(4, room.user_remove.callCount)
      assert.equal(5, room.user_remove.getCall(0).args[0].id)
      assert.equal(6, room.user_remove.getCall(1).args[0].id)
      assert.equal(3, room.user_remove.getCall(2).args[0].id)

    it 'with options', ->
      class R extends RoomGame
        user_add: -> spy.apply(@, arguments)
      new R({users: [{id: 2}, {id: 3}]})
      assert.equal(2, spy.callCount)
      assert.deepEqual({id: 2}, spy.getCall(0).args[0])
      assert.deepEqual({id: 3}, spy.getCall(1).args[0])

    it 'user_add', ->
      update = sinon.spy()
      room.on 'update', update
      room.id = 1
      room.emit_user_exec = spy = sinon.spy()
      room.users = []
      room.user_add({id: 5})
      assert.deepEqual([{id: 5}], room.users)
      assert.equal(1, spy.callCount)
      assert.equal(5, spy.getCall(0).args[0])
      assert.equal('_room_add', spy.getCall(0).args[1])
      assert.deepEqual({id: 1, module: 'RoomGame', type: 'user'}, spy.getCall(0).args[2])
      assert.equal(1, update.callCount)
      assert.deepEqual({users: [{id: 5}]}, update.getCall(0).args[0])

    it 'user_exist', ->
      room.user_get = sinon.fake.returns(-1)
      assert.equal(false, room.user_exist(4))
      assert.equal(1, room.user_get.callCount)
      assert.equal(4, room.user_get.getCall(0).args[0])
      assert.equal(true, room.user_get.getCall(0).args[1])
      room.user_get = sinon.fake.returns(0)
      assert.equal(true, room.user_exist(4))

    it 'spectator_exist', ->
      room.spectator_get = sinon.fake.returns(-1)
      assert.equal(false, room.spectator_exist(4))
      assert.equal(1, room.spectator_get.callCount)
      assert.equal(4, room.spectator_get.getCall(0).args[0])
      assert.equal(true, room.spectator_get.getCall(0).args[1])
      room.spectator_get = sinon.fake.returns(0)
      assert.equal(true, room.spectator_exist(4))

    it 'user_reconnect', ->
      room.id = 1
      room._disconected = [4, 5, 6]
      room.emit_user_exec = spy = sinon.spy()
      room.user_exist = sinon.fake.returns(true)
      assert.equal(true, room.user_reconnect(5))
      assert.deepEqual([4, 6], room._disconected)
      assert.equal(1, room.user_exist.callCount)
      assert.equal(5, room.user_exist.getCall(0).args[0])
      assert.equal(1, spy.callCount)
      assert.equal(5, spy.getCall(0).args[0])
      assert.equal('_room_add', spy.getCall(0).args[1])
      assert.deepEqual({id: 1, module: 'RoomGame', type: 'user'}, spy.getCall(0).args[2])

    it 'user_reconnect (spectator)', ->
      room.id = 1
      room.emit_user_exec = spy = sinon.spy()
      room.user_exist = sinon.fake.returns(false)
      room.spectator_exist = sinon.fake.returns(true)
      assert.equal(true, room.user_reconnect(5))
      assert.equal(1, room.spectator_exist.callCount)
      assert.equal(5, room.spectator_exist.getCall(0).args[0])
      assert.equal(1, spy.callCount)
      assert.equal('spectator', spy.getCall(0).args[2].type)

    it 'user_reconnect (not exist)', ->
      room._disconected = [4]
      room.emit_user_exec = sinon.spy()
      room.user_exist = sinon.fake.returns(false)
      room.spectator_exist = sinon.fake.returns(false)
      assert.equal(false, room.user_reconnect({id: 5}))
      assert.equal(0, room.emit_user_exec.callCount)
      assert.deepEqual([4], room._disconected)

    it 'user_get', ->
      assert.equal(5, room.user_get(5).id)
      assert.equal(0, room.user_get(5, true))
      assert.equal(undefined, room.user_get(10))

    it 'spectator_get', ->
      assert.equal(3, room.spectator_get(3).id)
      assert.equal(0, room.spectator_get(3, true))
      assert.equal(undefined, room.spectator_get(5))

    it 'user_remove', ->
      update = sinon.spy()
      room.on 'update', update
      room.id = 1
      room.emit_user_exec = sinon.spy()
      room.user_remove({id: 6})
      assert.deepEqual([{id: 5}], room.users)
      assert.deepEqual([{id: 3}, {id: 4}], room.spectators)
      assert.equal(1, room.emit_user_exec.callCount)
      assert.equal(6, room.emit_user_exec.getCall(0).args[0])
      assert.equal('_room_remove', room.emit_user_exec.getCall(0).args[1])
      assert.equal(1, room.emit_user_exec.getCall(0).args[2])
      assert.deepEqual([], room._disconected)
      assert.equal(1, update.callCount)
      assert.deepEqual({users: [{id: 5}]}, update.getCall(0).args[0])

    it 'user_remove (spectator)', ->
      update = sinon.spy()
      room.on 'update', update
      room.emit_user_exec = sinon.spy()
      room.user_remove({id: 4})
      assert.deepEqual([{id: 5}, {id: 6}], room.users)
      assert.deepEqual([{id: 3}], room.spectators)
      assert.equal(1, update.callCount)
      assert.deepEqual({spectators: [{id: 3}]}, update.getCall(0).args[0])

    it 'user_remove (disconnect)', ->
      room.emit_user_exec = sinon.spy()
      room.user_remove({id: 4, disconnect: true})
      assert.deepEqual([4], room._disconected)
      assert.equal(0, room.emit_user_exec.callCount)

    it 'user_to_specator', ->
      update = sinon.spy()
      room.user_exist = sinon.fake.returns true
      room.on 'update', update
      room.id = 1
      room.emit_user_exec = spy = sinon.spy()
      assert.equal(true, room.user_to_spectator({id: 6}))
      assert.equal(1, room.user_exist.callCount)
      assert.equal(6, room.user_exist.getCall(0).args[0])
      assert.deepEqual([{id: 5}], room.users)
      assert.deepEqual([{id: 3}, {id: 4}, {id: 6}], room.spectators)
      assert.equal(1, spy.callCount)
      assert.equal(6, spy.getCall(0).args[0])
      assert.equal('_room_update', spy.getCall(0).args[1])
      assert.deepEqual({id: 1, type: 'spectator'}, spy.getCall(0).args[2])
      assert.equal 1, update.callCount
      assert.deepEqual {users: [{id: 5}], spectators: [{id: 3}, {id: 4}, {id: 6}]}, update.getCall(0).args[0]

    it 'user_to_specator (not exist)', ->
      room.user_exist = sinon.fake.returns false
      assert.equal(false, room.user_to_spectator({id: 6}))
      assert.deepEqual([{id: 5}, {id: 6}], room.users)

    it 'emit_user_publish', ->
      User::emit_self_publish = spy = sinon.spy()
      room.emit_user_publish(5, 'ev', 'pr')
      assert.equal(1, spy.callCount)
      assert.equal(5, spy.getCall(0).args[0])
      assert.equal('ev', spy.getCall(0).args[1])
      assert.equal('pr', spy.getCall(0).args[2])

    it 'emit_user_publish (disconnected)', ->
      room._disconected = [5]
      User::emit_self_publish = spy = sinon.spy()
      room.emit_user_publish(5, 'ev', 'pr')
      assert.equal(0, spy.callCount)

    it 'publish', ->
      room.emit_user_publish = spy = sinon.spy()
      room.publish('ev', {p: 'r'})
      assert.equal(4, spy.callCount)
      assert.equal(5, spy.getCall(0).args[0])
      assert.equal('ev', spy.getCall(0).args[1])
      assert.deepEqual({p: 'r'}, spy.getCall(0).args[2])
      assert.equal(6, spy.getCall(1).args[0])
      assert.equal(3, spy.getCall(2).args[0])

    it 'publish (additional)', ->
      room.emit_user_publish = spy = sinon.spy()
      room.publish('ev', {p: 'pr'}, [ [6, {z: 'p'}] ])
      assert.deepEqual({p: 'pr'}, spy.getCall(0).args[2])
      assert.deepEqual({p: 'pr', z: 'p'}, spy.getCall(1).args[2])

    it 'publish (additional - objects)', ->
      room.emit_user_publish = spy = sinon.spy()
      room.publish('ev', {p: 'pr'}, {6: {z: 'p'} })
      assert.deepEqual({p: 'pr'}, spy.getCall(0).args[2])
      assert.deepEqual({p: 'pr', z: 'p'}, spy.getCall(1).args[2])

    it 'publish (additional - null)', ->
      room.emit_user_publish = spy = sinon.spy()
      room.publish('ev', {p: 'pr'}, null)
      assert.deepEqual({p: 'pr'}, spy.getCall(0).args[2])

    it 'emit_user_exec', ->
      User::emit_self_exec = spy = sinon.spy()
      room.emit_user_exec(5, 'me', 'pr')
      assert.equal(1, spy.callCount)
      assert.equal(5, spy.getCall(0).args[0])
      assert.equal('me', spy.getCall(0).args[1])
      assert.equal('pr', spy.getCall(0).args[2])


  describe 'Game', ->
    beforeEach ->
      RoomGame_methods.constructor = sinon.spy()
      room._game_start()
      room._game.waiting = -> 5
      room._game.move = spy = sinon.spy()

    it 'no class throw', ->
      room = new Room({})
      assert.throws -> room._game_start()

    it '_game_player_parse', ->
      fake = sinon.fake.returns {fa: 'ke'}
      room.game_player_params = {id: 'id', coins: 'co', fake}
      assert.deepEqual {id: 5, co: 2, fa: 'ke'}, room._game_player_parse({id: 5, coins: 2, fake: 'fu', touch: 'none'})
      assert.equal 1, fake.callCount
      assert.equal 'fu', fake.getCall(0).args[0]

    it 'pass options', ->
      RoomGame_methods.constructor = sinon.spy()
      room._game_player_parse = sinon.fake.returns {p: 'parsed'}
      room.users = [{id: 5}, {id: 6}]
      room._game_start({type: 'sng'})
      assert.deepEqual { type: 'sng', users: [{p: 'parsed'}, {p: 'parsed'}] }, RoomGame_methods.constructor.getCall(0).args[0]
      assert.equal 2, room._game_player_parse.callCount
      assert.deepEqual {id: 5}, room._game_player_parse.getCall(0).args[0]
      assert.deepEqual {id: 6}, room._game_player_parse.getCall(1).args[0]

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
      room._game.fold = sinon.spy()
      room._game_exec({user_id: 15, method: 'fold', params: {p: 'pr'}})
      assert.equal(0, room._game.fold.callCount)
