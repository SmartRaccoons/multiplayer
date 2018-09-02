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
      emit_all_exec: sinon.spy()

  afterEach ->
    clock.restore()

  describe 'User', ->
    user = null
    beforeEach ->
      PubsubModule_methods.constructor = sinon.spy()
      PubsubModule_methods.remove = sinon.spy()
      user = new User({id: 5, socket: socket})
      user.id = 5
      user.emit_module_exec = sinon.spy()

    it 'default attributes', ->
      user = new User({socket: socket})
      assert.equal('user', user._module)
      assert(user.attributes.alive.getTime() <= new Date().getTime())

    it 'publish user data on constructor', ->
      spy = sinon.spy()
      class UserPublish extends User
        publish: -> spy.apply(@, arguments)
        data: -> 'd'
      new UserPublish({id: 2, socket: socket})
      assert.equal(1, spy.callCount)
      assert.equal('authenticate:success', spy.getCall(0).args[0])
      assert.equal('d', spy.getCall(0).args[1])

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
      assert.deepEqual({id: 5}, PubsubModule_methods.constructor.getCall(0).args[0])

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

    it '_room_add', ->
      assert.notEqual(1, user.room)
      user.publish = sinon.spy()
      user._room_add(1)
      assert.equal(1, user.room)
      assert.equal(1, user.publish.callCount)
      assert.equal('room:add', user.publish.getCall(0).args[0])
      assert.equal(1, user.publish.getCall(0).args[1])

    it 'room remove', ->
      user.publish = sinon.spy()
      user.room = 1
      user._room_remove()
      assert.notEqual(1, user.room)
      assert.equal(1, user.publish.callCount)
      assert.equal('room:remove', user.publish.getCall(0).args[0])

    it 'room exec', ->
      user.room = {id: 1}
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

    it '_room_update', ->
      user.publish = sinon.spy()
      user.room = null
      user._room_update('room')
      assert.equal('room', user.room)
      assert.equal(1, user.publish.callCount)
      assert.equal('room:update', user.publish.getCall(0).args[0])
      assert.equal('room', user.publish.getCall(0).args[1])

    it 'rooms_lobby_add', ->
      user.data_public = sinon.fake.returns({id: 5})
      user.rooms_lobby_add()
      assert.equal(1, _pubsub.emit_server_master_exec.callCount)
      assert.equal('rooms', _pubsub.emit_server_master_exec.getCall(0).args[0])
      assert.equal('lobby_add', _pubsub.emit_server_master_exec.getCall(0).args[1])
      assert.deepEqual({id: 5}, _pubsub.emit_server_master_exec.getCall(0).args[2])
      assert.equal(1, user.data_public.callCount)

    it 'rooms_lobby_add (params)', ->
      user.data_public = sinon.fake.returns({id: 5})
      user.rooms_lobby_add('tournaments', {id: 4, z: 5})
      assert.equal('tournaments', _pubsub.emit_server_master_exec.getCall(0).args[0])
      assert.deepEqual({id: 4, z: 5}, _pubsub.emit_server_master_exec.getCall(0).args[2])

    it 'rooms_lobby_remove', ->
      user.id = 5
      user.rooms_lobby_remove()
      assert.equal(1, _pubsub.emit_server_master_exec.callCount)
      assert.equal('rooms', _pubsub.emit_server_master_exec.getCall(0).args[0])
      assert.equal('lobby_remove', _pubsub.emit_server_master_exec.getCall(0).args[1])
      assert.equal(5, _pubsub.emit_server_master_exec.getCall(0).args[2])

    it 'rooms_lobby_remove (params)', ->
      user.rooms_lobby_remove('tournaments')
      assert.equal('tournaments', _pubsub.emit_server_master_exec.getCall(0).args[0])

    it 'rooms_reconnect', ->
      user.id = 5
      user.rooms_reconnect()
      assert.equal(1, _pubsub.emit_all_exec.callCount)
      assert.equal('rooms', _pubsub.emit_all_exec.getCall(0).args[0])
      assert.equal('_objects_exec', _pubsub.emit_all_exec.getCall(0).args[1])
      assert.deepEqual({user_reconnect: 5}, _pubsub.emit_all_exec.getCall(0).args[2])

    it 'rooms_reconnect (params)', ->
      user.rooms_reconnect('tours')
      assert.equal('tours', _pubsub.emit_all_exec.getCall(0).args[0])

    it '_lobby_add', ->
      user.publish = sinon.spy()
      user._lobby_add({p: 'a'})
      assert.equal(1, user.publish.callCount)
      assert.equal('lobby:add', user.publish.getCall(0).args[0])
      assert.deepEqual({p: 'a'}, user.publish.getCall(0).args[1])

    it '_lobby_remove', ->
      user.publish = sinon.spy()
      user._lobby_remove({p: 'a'})
      assert.equal(1, user.publish.callCount)
      assert.equal('lobby:remove', user.publish.getCall(0).args[0])
      assert.deepEqual({p: 'a'}, user.publish.getCall(0).args[1])

    it 'remove user', ->
      user.room_exec = sinon.spy()
      PubsubModule_methods.remove = sinon.spy()
      user.attributes.socket.disconnect = sinon.spy()
      user.remove()
      assert.equal(1, PubsubModule_methods.remove.callCount)
      assert.equal(1, user.room_exec.callCount)
      assert.equal('user_remove', user.room_exec.getCall(0).args[0])
      assert.deepEqual({id: 5, disconnect: true}, user.room_exec.getCall(0).args[1])
      assert.equal(1, user.attributes.socket.disconnect.callCount)
      assert.equal(null, user.attributes.socket.disconnect.getCall(0).args[0])

    it 'remove user (duplicate)', ->
      user.room_exec = sinon.spy()
      user.attributes.socket.disconnect = sinon.spy()
      user.remove('duplicate')
      assert.equal('duplicate', user.attributes.socket.disconnect.getCall(0).args[0])

    it 'remove user (2 times)', ->
      user.room_exec = sinon.spy()
      user.attributes.socket.disconnect = sinon.spy()
      user.remove()
      user.remove()
      assert.equal(1, user.room_exec.callCount)

    it 'room_left', ->
      user.room_exec = spy = sinon.spy()
      user.room_left()
      assert.equal(0, spy.callCount)
      user.room = {id: 2, type: 'user'}
      user.room_left()
      assert.equal(0, spy.callCount)
      user.room = {id: 2, type: 'spectator'}
      user.room_left()
      assert.equal(1, spy.callCount)
      assert.equal('user_remove', spy.getCall(0).args[0])
      assert.deepEqual({id: 5}, spy.getCall(0).args[1])

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
      user.room = '5'
      clock.tick(11 * 60 * 1000)
      assert.equal(true, user.alive())
      clock.tick(61 * 60 * 1000)
      assert.equal(false, user.alive())


  describe 'User events', ->
    user = null
    socket = null
    beforeEach ->
      socket = new events.EventEmitter()
      socket.send = sinon.spy()
      user = new User({id: 5, socket: socket})
      user.room = 3
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
      socket.emit 'remove'
      assert.equal(1, user.remove.callCount)
