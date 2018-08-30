events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class Login
  _attr:
    'id': {db: true}
    'name': {default: '', db: true}
    'new': {private: true}
    'coins': {private: true}
    'language': {private: true}
  _user_update: ->

class Room
  game_methods:
    'move':
      validate: (v)->
        if v.hand > 0
          return {hand: 5}
        return false
    'move2': {}

PubsubModule_methods =
  constructor: ->
  remove: ->


_pubsub = {}
User = proxyquire('../user', {
  '../../config':
    config_callback: (c)-> c
    module_get: (module)->
      if 'server.room.authorize' is module
        return {Login}
      return {Room}
  '../pubsub/multiserver':
    PubsubModule: class PubsubModule
      constructor: -> PubsubModule_methods.constructor.apply(@, arguments)
      remove: -> PubsubModule_methods.remove.apply(@, arguments)
    PubsubServer: class PubsubServer
      _pubsub: -> _pubsub
}).User


describe 'User', ->
  spy = null
  socket = null
  clock = null
  beforeEach ->
    Login::_attr =
      'id': {db: true}
      'name': {default: '', db: true}
      'new': {private: true}
      'coins': {private: true}
      'language': {private: true}
    clock = sinon.useFakeTimers()
    socket =
      id: 777
      send: sinon.spy()
      on: sinon.spy()
    spy = sinon.spy()
    _pubsub =
      emit_server_master_exec: sinon.spy()

  afterEach ->
    clock.restore()

  describe 'User', ->
    user = null
    beforeEach ->
      PubsubModule_methods.constructor = sinon.spy()
      PubsubModule_methods.remove = sinon.spy()
      user = new User({id: 5, socket: socket})
      user.emit_module_exec = sinon.spy()

    it 'default attributes', ->
      user = new User({socket: socket})
      assert.equal('user', user._module)
      assert(user.attributes.alive.getTime() <= new Date().getTime())

    it 'publish', ->
      socket.send = sinon.spy()
      user.publish('ev', 'pr')
      assert.equal(1, socket.send.callCount)
      assert.equal('ev', socket.send.getCall(0).args[0])
      assert.equal('pr', socket.send.getCall(0).args[1])

    it 'publish pubsub', ->
      socket.send = sinon.spy()
      user.publish(['ev', 'pr'])
      assert.equal(1, socket.send.callCount)
      assert.equal('ev', socket.send.getCall(0).args[0])
      assert.equal('pr', socket.send.getCall(0).args[1])

    it 'get', ->
      assert.equal(5, user.get('id'))

    it 'pubsub listen', ->
      assert.equal(1, PubsubModule_methods.constructor.callCount)

    it 'emit_self_publish', ->
      user.emit_self_exec = sinon.spy()
      user.emit_self_publish('3', 'ev', 'pr')
      assert.equal(1, user.emit_self_exec.callCount)
      assert.equal('3', user.emit_self_exec.getCall(0).args[0])
      assert.equal('publish', user.emit_self_exec.getCall(0).args[1])
      assert.deepEqual(['ev', 'pr'], user.emit_self_exec.getCall(0).args[2])

    it 'data', ->
      user = new User({id: 5, name: 'b', new: true, socket: socket})
      assert.deepEqual({id: 5, name: 'b', new: true}, user.data())

    it 'data public', ->
      user = new User({id: 5, name: 'b', new: true, socket: socket})
      assert.deepEqual({id: 5, name: 'b'}, user.data_public())

    it 'room set', ->
      assert.notEqual(1, user.room)
      user.room_set(1)
      assert.equal(1, user.room)

    it 'room remove', ->
      user.publish = sinon.spy()
      user.room_set(1)
      user.room_remove()
      assert.notEqual(1, user.room)
      assert.equal(1, user.publish.callCount)
      assert.equal('rooms:remove', user.publish.getCall(0).args[0])

    it 'room exec', ->
      user.room_set(1)
      Room::emit_self_exec = spy = sinon.spy()
      user.room_exec('game', 'pr')
      assert.equal(1, spy.callCount)
      assert.equal(1, spy.getCall(0).args[0])
      assert.equal('game', spy.getCall(0).args[1])
      assert.equal('pr', spy.getCall(0).args[2])

    it 'room exec game', ->
      user.room_exec = spy = sinon.spy()
      user.room_exec_game('mt', 'pr')
      assert.equal(1, spy.callCount)
      assert.equal('_game_exec', spy.getCall(0).args[0])
      assert.deepEqual({user_id: 5, method: 'mt', params: 'pr'}, spy.getCall(0).args[1])

    it 'room exec (no room)', ->
      user.room_exec('game', 'pr')
      assert.equal(0, user.emit_module_exec.callCount)

    it 'rooms_join', ->
      user.data_public = sinon.fake.returns({id: 5})
      user.rooms_join()
      assert.equal(1, _pubsub.emit_server_master_exec.callCount)
      assert.equal('rooms', _pubsub.emit_server_master_exec.getCall(0).args[0])
      assert.equal('lobby_add', _pubsub.emit_server_master_exec.getCall(0).args[1])
      assert.deepEqual({id: 5}, _pubsub.emit_server_master_exec.getCall(0).args[2])
      assert.equal(1, user.data_public.callCount)

    it 'rooms_join (params)', ->
      user.data_public = sinon.fake.returns({id: 5})
      user.rooms_join('tournaments', {id: 4, z: 5})
      assert.equal('tournaments', _pubsub.emit_server_master_exec.getCall(0).args[0])
      assert.deepEqual({id: 4, z: 5}, _pubsub.emit_server_master_exec.getCall(0).args[2])

    it 'lobby_join', ->
      user.publish = sinon.spy()
      user.lobby_join({p: 'a'})
      assert.equal(1, user.publish.callCount)
      assert.equal('lobby:join', user.publish.getCall(0).args[0])
      assert.deepEqual({p: 'a'}, user.publish.getCall(0).args[1])

    it 'lobby_remove', ->
      user.publish = sinon.spy()
      user.lobby_remove({p: 'a'})
      assert.equal(1, user.publish.callCount)
      assert.equal('lobby:remove', user.publish.getCall(0).args[0])
      assert.deepEqual({p: 'a'}, user.publish.getCall(0).args[1])

    it 'remove user', ->
      user.room_exec = sinon.spy()
      PubsubModule_methods.remove = sinon.spy()
      user.remove()
      assert.equal(1, PubsubModule_methods.remove.callCount)
      assert.equal(1, user.room_exec.callCount)
      assert.equal('remove_user', user.room_exec.getCall(0).args[0])
      assert.equal(5, user.room_exec.getCall(0).args[1])

    it 'set', ->
      user.set({alive: 'alive'})
      assert.equal('alive', user.attributes.alive)

    it 'set (publish)', ->
      user.publish = sinon.spy()
      user.set({coins: 30, alive: 'alive'})
      assert.equal(1, user.publish.callCount)
      assert.equal('user:set', user.publish.getCall(0).args[0])
      assert.deepEqual({coins: 30}, user.publish.getCall(0).args[1])

    it 'set (no params)', ->
      Login::_user_update = spy = sinon.spy()
      user.publish = sinon.spy()
      user.set({alive: 'alive'})
      assert.equal(0, user.publish.callCount)
      assert.equal(0, spy.callCount)

    it 'set (Login update)', ->
      Login::_user_update = spy = sinon.spy()
      user.set({coins: 1444, new: true})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5, coins: 1444, new: true}, spy.getCall(0).args[0])

    it 'set (Login update silent)', ->
      Login::_user_update = spy = sinon.spy()
      user.set({coins: 1444}, true)
      assert.equal(0, spy.callCount)

    it 'set (socket)', ->
      user._bind_socket = sinon.spy()
      user.set({socket: 's'})
      assert.equal(1, user._bind_socket.callCount)

    it 'alive', ->
      assert.equal(true, user.alive())
      clock.tick(11 * 60 * 1000)
      assert.equal(false, user.alive())

    it 'alive (in room)', ->
      user.room_set('5')
      clock.tick(11 * 60 * 1000)
      assert.equal(true, user.alive())
      clock.tick(61 * 60 * 1000)
      assert.equal(false, user.alive())


  describe 'User events', ->
    user = null
    socket = null
    beforeEach ->
      socket = new events.EventEmitter()
      user = new User({id: 5, socket: socket})
      user.room_set(3)
      user.room_exec = sinon.spy()

    it 'alive', ->
      clock.tick(10 * 1000)
      socket.emit 'alive'
      assert.equal(user.get('alive').getTime(), new Date().getTime())

    it 'user:update', ->
      Login::_attr.language.validate = -> 'en'
      Login::_attr.name.validate = -> 'mi'
      Login::_attr.coins.validate = -> 3
      user.set = sinon.spy()
      socket.emit 'user:update', {language: 'somalian', name: 'm'}
      assert.equal(1, user.set.callCount)
      assert.deepEqual({language: 'en', name: 'mi'}, user.set.getCall(0).args[0])

    it 'user:update (no validate params)', ->
      user.set = sinon.spy()
      socket.emit 'user:update', {language: 'somalian'}
      assert.equal(0, user.set.callCount)

    it 'user:update (no params)', ->
      user.set = sinon.spy()
      socket.emit 'user:update'
      assert.equal(0, user.set.callCount)

    it 'game', ->
      user.room_exec_game = sinon.spy()
      socket.emit 'game:move', {hand: 4}
      assert.equal(1, user.room_exec_game.callCount)
      assert.equal('move', user.room_exec_game.getCall(0).args[0])
      assert.deepEqual({hand: 5}, user.room_exec_game.getCall(0).args[1])

    it 'game (not validates)', ->
      user.room_exec_game = sinon.spy()
      socket.emit 'game:move', {hand: 0}
      assert.equal(0, user.room_exec_game.callCount)

    it 'game (no params)', ->
      user.room_exec_game = sinon.spy()
      socket.emit 'game:move'
      assert.equal(0, user.room_exec_game.callCount)

    it 'game (no validate)', ->
      user.room_exec_game = sinon.spy()
      socket.emit 'game:move2', {hand: 5}
      assert.equal(0, user.room_exec_game.callCount)

    it 'socket remove_callback', ->
      user.remove = sinon.spy()
      socket.remove_callback()
      assert.equal(0, user.remove.callCount)

    it 'socket remove_callback (immediate)', ->
      user.remove = sinon.spy()
      socket.remove_callback(true)
      assert.equal(1, user.remove.callCount)
