SimpleEvent = require('simple.event').SimpleEvent
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

class Room2
  game_methods:
    'move2':
      validate: (v)-> {z: v.hand}


PubsubModule_methods =
  constructor: ->
  remove: ->


_pubsub = {}
config = {}
config_callbacks = []
User = proxyquire('../user', {
  '../../config':
    config_callback: (c)->
      config_callbacks.push c
      c
    module_get: (module)->
      if 'server.authorize' is module
        return {Login}
      return {Room, Room2, User}
    config_get: (param)-> config[param]
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
  db = {}
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
    config =
      db: db
    config_callbacks[0]()
    db.select_one = sinon.spy()
    db.insert = sinon.spy()
    db.select = sinon.spy()

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

    it 'config (coins buy params)', ->
      User::_coins_buy_params =
        type: 8
        service:
          1: 250
      config_callbacks[0]()
      User::emit_self_exec = spy = sinon.spy()
      complete = sinon.spy()
      User::_coins_buy_callback[1]({user_id: 5, service: 1, complete})
      assert.equal 1, spy.callCount
      assert.equal 5, spy.getCall(0).args[0]
      assert.equal 'set_coins', spy.getCall(0).args[1]
      assert.deepEqual {type: 8, coins: 250}, spy.getCall(0).args[2]
      spy.getCall(0).args[3]()
      assert.equal 1, complete.callCount

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

    it 'bonuses', ->
      class UserBonus extends User
        _coins_bonus_params:
          'daily': {}
          'share': {}
        _coins_bonus: -> spy.apply(@, arguments)
      new UserBonus({id: 3, socket})
      assert.equal 2, spy.callCount
      assert.equal 'daily', spy.getCall(0).args[0]
      assert.equal 'share', spy.getCall(1).args[0]

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
      user.room = {id: 1, module: 'Room'}
      Room::emit_self_exec = spy = sinon.spy()
      user.room_exec('game', 'pr')
      assert.equal(1, spy.callCount)
      assert.equal(1, spy.getCall(0).args[0])
      assert.equal('game', spy.getCall(0).args[1])
      assert.equal('pr', spy.getCall(0).args[2])

    it 'room exec', ->
      user.room = {id: 1, module: 'Room2'}
      Room2::emit_self_exec = spy = sinon.spy()
      user.room_exec('game', 'pr')
      assert.equal(1, spy.callCount)

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
      user.room = {id: 2}
      user._room_update({ben: 'room'})
      assert.deepEqual({id: 2, ben: 'room'}, user.room)
      assert.equal(1, user.publish.callCount)
      assert.equal('room:update', user.publish.getCall(0).args[0])
      assert.deepEqual({ben: 'room'}, user.publish.getCall(0).args[1])

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
      assert.deepEqual({id: 5}, _pubsub.emit_server_master_exec.getCall(0).args[2])
      assert.deepEqual({id: 4, z: 5}, _pubsub.emit_server_master_exec.getCall(0).args[3])

    it 'rooms_lobby_remove', ->
      user.id = 5
      user.rooms_lobby_remove()
      assert.equal(1, _pubsub.emit_server_master_exec.callCount)
      assert.equal('rooms', _pubsub.emit_server_master_exec.getCall(0).args[0])
      assert.equal('lobby_remove', _pubsub.emit_server_master_exec.getCall(0).args[1])
      assert.equal(5, _pubsub.emit_server_master_exec.getCall(0).args[2])

    it 'rooms_lobby_remove (params)', ->
      user.rooms_lobby_remove('tournaments', 'p2')
      assert.equal('tournaments', _pubsub.emit_server_master_exec.getCall(0).args[0])
      assert.equal('p2', _pubsub.emit_server_master_exec.getCall(0).args[3])

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

    it '_set_db', ->
      Login::_user_update = spy = sinon.spy()
      user._set_db({id: 5})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5}, spy.getCall(0).args[0])

    it 'set', ->
      user.set({alive: 'alive'})
      assert.equal('alive', user.attributes.alive)

    it 'set (socket)', ->
      user._bind_socket = sinon.spy()
      user.set({socket: 's'})
      assert.equal(1, user._bind_socket.callCount)

    it 'set (publish)', ->
      user.publish = sinon.spy()
      user.set({new: true})
      assert.equal(1, user.publish.callCount)
      assert.equal('user:set', user.publish.getCall(0).args[0])
      assert.deepEqual({new: true}, user.publish.getCall(0).args[1])

    it 'set (publish no params)', ->
      user.publish = sinon.spy()
      user.set({alive: 'a'})
      assert.equal(0, user.publish.callCount)

    it 'set (ifoffline)', ->
      user._set_db = sinon.spy()
      user.id = 5
      user.set({new: true})
      assert.equal 1, user._set_db.callCount
      assert.deepEqual {id: 5, new: true}, user._set_db.getCall(0).args[0]

    it 'set (ifoffline silent)', ->
      user._set_db = sinon.spy()
      user.set({new: true}, true)
      assert.equal 0, user._set_db.callCount

    it 'set_ifoffline', ->
      user._set_db = spy = sinon.spy()
      user.set_ifoffline(5, {d: 'a'})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5, d: 'a'}, spy.getCall(0).args[0])

    it '_set_coins_db', ->
      user._set_coins_db {user_id: 1, type: 2, coins: 5}
      assert.equal 1, db.insert.callCount
      assert.equal 'coins_history', db.insert.getCall(0).args[0].table
      assert.deepEqual {user_id: 1, action: new Date(), type: 2, coins: 5}, db.insert.getCall(0).args[0].data

    it 'set_coins', ->
      user.attributes.coins_history = [{coins: 2}]
      user.set = sinon.spy()
      user._set_coins_db = sinon.spy()
      user.attributes.coins = 10
      user.set_coins {type: 2, coins: 5}
      assert.equal 1, user.set.callCount
      assert.deepEqual {coins: 15}, user.set.getCall(0).args[0]
      assert.equal 1, user._set_coins_db.callCount
      assert.deepEqual {user_id: 5, type: 2, coins: 5}, user._set_coins_db.getCall(0).args[0]
      assert.deepEqual [{action: new Date(), type: 2, coins: 5}, {coins: 2}], user.attributes.coins_history

    it 'set_coins (no history)', ->
      user.set = ->
      user._set_coins_db = ->
      user.attributes.coins = 10
      user.set_coins {type: 2, coins: 5}
      assert.ok !user.attributes.coins_history?

    it 'set_coins (ifoffline)', ->
      user._set_db = sinon.spy()
      user._set_coins_db = sinon.spy()
      user.set_coins_ifoffline 2, {type: 2, coins: 5}
      assert.equal 1, user._set_coins_db.callCount
      assert.deepEqual {user_id: 2, type: 2, coins: 5}, user._set_coins_db.getCall(0).args[0]
      assert.equal 1, user._set_db.callCount
      assert.deepEqual {id: 2, coins: {increase: 5}}, user._set_db.getCall(0).args[0]

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
      socket = new SimpleEvent()
      socket.send = sinon.spy()
      user = new User({id: 5, socket: socket, language: 'en', api: {buy: sinon.spy()}})
      user.room = {id: 3, module: 'Room'}
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

    it 'game (no room)', ->
      user.room = null
      user.room_exec_game = sinon.spy()
      socket.emit 'game:move', {hand: 4}
      assert.equal(0, user.room_exec_game.callCount)

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

    it 'game (Room2)', ->
      user.room = {id: 1, module: 'Room2'}
      user.room_exec_game = sinon.spy()
      socket.emit 'game:move2', {hand: 5}
      assert.equal(1, user.room_exec_game.callCount)
      assert.equal 'move2', user.room_exec_game.getCall(0).args[0]
      assert.deepEqual {z: 5}, user.room_exec_game.getCall(0).args[1]

    it 'socket remove_callback', ->
      user.remove = sinon.spy()
      socket.emit 'remove'
      assert.equal(1, user.remove.callCount)

    it '_bind_socket_coins_buy (facebook)', ->
      db.select = sinon.spy()
      user.id = 5
      user.publish = sinon.spy()
      user.attributes.api._name = 'facebook'
      user._bind_socket_coins_buy()
      socket.emit 'coins:buy:facebook', 2
      assert.equal 1, user.attributes.api.buy.callCount
      assert.deepEqual {service: 2, user_id: 5, language: 'en'} , user.attributes.api.buy.getCall(0).args[0]
      user.attributes.api.buy.getCall(0).args[1]({id: 10})
      assert.equal 'coins:buy:facebook', user.publish.getCall(0).args[0]
      assert.deepEqual {service: 2, id: 10}, user.publish.getCall(0).args[1]

    it '_bind_socket_coins_buy (draugiem)', ->
      db.select = sinon.spy()
      user.id = 5
      user.publish = sinon.spy()
      user.attributes.api._name = 'draugiem'
      user._bind_socket_coins_buy()
      socket.emit 'coins:buy:draugiem', 2
      user.attributes.api.buy.getCall(0).args[1]({id: 10})
      assert.equal 'coins:buy:draugiem', user.publish.getCall(0).args[0]

    it '_bind_socket_coins_buy (inbox)', ->
      db.select = sinon.spy()
      user.id = 5
      user.publish = sinon.spy()
      user.attributes.api._name = 'inbox'
      user._bind_socket_coins_buy()
      socket.emit 'coins:buy:inbox', 2
      user.attributes.api.buy.getCall(0).args[1]({id: 10})
      assert.equal 'coins:buy:inbox', user.publish.getCall(0).args[0]

    it '_bind_socket_coins_buy (not included)', ->
      db.select = sinon.spy()
      user.id = 5
      user.publish = sinon.spy()
      user.attributes.api._name = 'inbox'
      user._bind_socket_coins_buy(['facebook'])
      socket.emit 'coins:buy:inbox', 2
      assert.equal 0, user.attributes.api.buy.callCount

    it '_bind_socket_coins_buy (unexisting)', ->
      db.select = sinon.spy()
      user.id = 5
      user.publish = sinon.spy()
      user.attributes.api._name = 'boom'
      user._bind_socket_coins_buy()
      socket.emit 'coins:buy:inbox', 2
      socket.emit 'coins:buy:boom', 2
      assert.equal 0, user.attributes.api.buy.callCount

    it '_bind_socket_coins_history', ->
      db.select = sinon.spy()
      user.id = 5
      user.publish = sinon.spy()
      user._bind_socket_coins_history()
      socket.emit 'coins:history'
      assert.equal 1, db.select.callCount
      assert.equal 'coins_history', db.select.getCall(0).args[0].table
      assert.deepEqual {user_id: 5}, db.select.getCall(0).args[0].where
      assert.equal 10, db.select.getCall(0).args[0].limit
      assert.deepEqual ['-action'], db.select.getCall(0).args[0].order
      assert.deepEqual ['coins', 'action', 'type'], db.select.getCall(0).args[0].select
      db.select.getCall(0).args[1]([{coins: 5}])
      assert.deepEqual [{coins: 5}], user.attributes.coins_history
      assert.equal 1, user.publish.callCount
      assert.equal 'coins:history', user.publish.getCall(0).args[0]
      assert.deepEqual [{coins: 5}], user.publish.getCall(0).args[1]

    it '_bind_socket_coins_history (fetched)', ->
      db.select = sinon.spy()
      user.id = 5
      user.publish = sinon.spy()
      user.attributes.coins_history = []
      user._bind_socket_coins_history()
      socket.emit 'coins:history'
      assert.equal 0, db.select.callCount
      assert.deepEqual [], user.publish.getCall(0).args[1]


  describe 'bonuses', ->
    user = null
    beforeEach ->
      user = new User({id: 5, socket: socket})
      user._coins_bonus_params =
        daily:
          after: 60 * 60 * 8
          type: 1
          coins: 150
        share:
          after: 60 * 60 * 10
          type: 3
          coins: 50
      user.id = 5

    it '__coins_bonus_check', ->
      user.__coins_bonus_check 'daily', spy
      assert.equal 1, db.select_one.callCount
      assert.deepEqual ['action'], db.select_one.getCall(0).args[0].select
      assert.equal 'coins_history', db.select_one.getCall(0).args[0].table
      assert.deepEqual {user_id: 5, type: 1}, db.select_one.getCall(0).args[0].where
      assert.deepEqual ['-action'], db.select_one.getCall(0).args[0].order
      d = new Date()
      d.setSeconds(d.getMinutes() - 60 * 60)
      config.db.select_one.getCall(0).args[1]({action: d})
      assert.equal(1, spy.callCount)
      assert.equal(60 * 60 * 7, spy.getCall(0).args[0])

    it '__coins_bonus_check (share)', ->
      user.__coins_bonus_check 'share', spy
      assert.equal 3, db.select_one.getCall(0).args[0].where.type
      d = new Date()
      d.setSeconds(d.getMinutes() - 60 * 60)
      config.db.select_one.getCall(0).args[1]({action: d})
      assert.equal(60 * 60 * 9, spy.getCall(0).args[0])

    it '__coins_bonus_check (passed)', ->
      user.__coins_bonus_check 'daily', spy
      d = new Date()
      d.setSeconds(d.getMinutes() - 60 * 60 * 10)
      config.db.select_one.getCall(0).args[1]({action: d})
      assert.equal(1, spy.callCount)
      assert.equal(0, spy.getCall(0).args[0])

    it '__coins_bonus_check (no entries)', ->
      user.__coins_bonus_check 'daily', spy
      config.db.select_one.getCall(0).args[1](null)
      assert.equal(0, spy.getCall(0).args[0])

    it '_coins_bonus', ->
      user.__coins_bonus_check = sinon.spy()
      user.publish = sinon.spy()
      user.set_coins = sinon.spy()
      socket.on = sinon.spy()
      user._coins_bonus('daily')
      assert.equal 1, user.__coins_bonus_check.callCount
      assert.equal 'daily', user.__coins_bonus_check.getCall(0).args[0]
      user.__coins_bonus_check.getCall(0).args[1](0)
      assert.equal 1, user.publish.callCount
      assert.equal 'coins:bonus:daily', user.publish.getCall(0).args[0]
      assert.deepEqual {left: 0, coins: 150}, user.publish.getCall(0).args[1]
      assert.equal(1, socket.on.callCount)
      assert.equal('coins:bonus:daily', socket.on.getCall(0).args[0])
      socket.on.getCall(0).args[1]()
      assert.equal 2, user.__coins_bonus_check.callCount
      assert.equal 'daily', user.__coins_bonus_check.getCall(1).args[0]
      user.__coins_bonus_check.getCall(1).args[1](0)
      assert.equal(1, user.set_coins.callCount)
      assert.deepEqual({type: 1, coins: 150}, user.set_coins.getCall(0).args[0])
      assert.equal 'coins:bonus:daily', user.publish.getCall(1).args[0]
      assert.deepEqual {left: 60*60*8, coins: 150}, user.publish.getCall(1).args[1]

    it '_coins_bonus (share)', ->
      user.__coins_bonus_check = sinon.spy()
      user.publish = sinon.spy()
      user.set_coins = sinon.spy()
      socket.on = sinon.spy()
      user._coins_bonus('share')
      assert.equal 'share', user.__coins_bonus_check.getCall(0).args[0]
      user.__coins_bonus_check.getCall(0).args[1](0)
      assert.equal 'coins:bonus:share', user.publish.getCall(0).args[0]
      assert.equal 50, user.publish.getCall(0).args[1].coins
      assert.equal('coins:bonus:share', socket.on.getCall(0).args[0])
      socket.on.getCall(0).args[1]()
      assert.equal 'share', user.__coins_bonus_check.getCall(1).args[0]
      user.__coins_bonus_check.getCall(1).args[1](0)
      assert.deepEqual({type: 3, coins: 50}, user.set_coins.getCall(0).args[0])
      assert.equal 'coins:bonus:share', user.publish.getCall(1).args[0]
      assert.deepEqual {left: 60*60*10, coins: 50}, user.publish.getCall(1).args[1]

    it '_coins_daily (left error)', ->
      user.__coins_bonus_check = sinon.spy()
      user.publish = sinon.spy()
      user.set_coins = sinon.spy()
      socket.on = sinon.spy()
      user._coins_bonus('daily')
      user.__coins_bonus_check.getCall(0).args[1](0)
      socket.on.getCall(0).args[1]()
      user.__coins_bonus_check.getCall(1).args[1](10)
      assert.equal(0, user.set_coins.callCount)
      assert.deepEqual {left: 10, coins: 150}, user.publish.getCall(1).args[1]
