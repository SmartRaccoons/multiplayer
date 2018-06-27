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

config = {}
User = proxyquire('../user', {
  '../../config':
    config_get: (param)-> config[param]
    config_callback: (c)-> c
    module_get: -> {Login}
}).User


describe 'User', ->
  db = null
  spy = null
  spy2 = null
  socket = null
  clock = null
  pubsub = {}
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
    spy2 = sinon.spy()
    config.pubsub = pubsub
    pubsub.remove_user = sinon.spy()
    pubsub.on_user = sinon.spy()
    pubsub.on_user_exec = sinon.spy()
    pubsub.emit_users_exec = sinon.spy()
    pubsub.emit_room_exec = sinon.spy()
    pubsub.emit_server_master_exec = sinon.spy()
    pubsub.on_users_exec = sinon.spy()
    pubsub.emit_user_exec = sinon.spy()

  afterEach ->
    clock.restore()

  describe 'User', ->
    user = null
    beforeEach ->
      user = new User({id: 5, socket: socket})
      # user.publish = sinon.spy()

    it 'default attributes', ->
      user = new User({socket: socket})
      assert(user.attributes.alive.getTime() <= new Date().getTime())

    it 'get', ->
      assert.equal(5, user.get('id'))

    it 'pubsub listen', ->
      assert.equal(1, pubsub.on_user.callCount)
      assert.equal(5, pubsub.on_user.getCall(0).args[0])
      pubsub.on_user.getCall(0).args[1]({event: 'ev', params: 'pr'})
      assert.equal(1, socket.send.callCount)
      assert.equal('ev', socket.send.getCall(0).args[0])
      assert.equal('pr', socket.send.getCall(0).args[1])

    it 'pubsub exec', ->
      assert.equal(1, pubsub.on_user_exec.callCount)
      assert.equal(5, pubsub.on_user_exec.getCall(0).args[0])
      user.mt = sinon.spy()
      pubsub.on_user_exec.getCall(0).args[1]({method: 'mt', params: 'pr'})
      assert.equal(1, user.mt.callCount)
      assert.equal('pr', user.mt.getCall(0).args[0])

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
      user.room_exec('game', 'pr')
      assert.equal(1, pubsub.emit_room_exec.callCount)
      assert.equal(1, pubsub.emit_room_exec.getCall(0).args[0])
      assert.equal('game', pubsub.emit_room_exec.getCall(0).args[1])
      assert.equal('pr', pubsub.emit_room_exec.getCall(0).args[2])

    it 'room exec (no room)', ->
      user.room_exec('game', 'pr')
      assert.equal(0, pubsub.emit_room_exec.callCount)

    it 'remove user', ->
      user.room_exec = sinon.spy()
      user.remove()
      assert.equal(1, pubsub.remove_user.callCount)
      assert.equal(user.id(), pubsub.remove_user.getCall(0).args[0])
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
      clock.tick(20 * 60 * 1000)
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

    it 'socket remove_callback', ->
      user.remove = sinon.spy()
      socket.remove_callback()
      assert.equal(0, user.remove.callCount)

    it 'socket remove_callback (immediate)', ->
      user.remove = sinon.spy()
      socket.remove_callback(true)
      assert.equal(1, user.remove.callCount)
