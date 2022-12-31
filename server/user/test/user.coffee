SimpleEvent = require('simple.event').SimpleEvent
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class Login
  _opt:
    'id': {db: true, public: true}
    'name': {default: '', db: true, public: true}
    'new': {}
    'coins': {}
    'language': {}
    'password': {private: true}
  _user_update: ->


class Cordova
  buy_complete: ->

class LoginInbox
  buy: ->

class Room
  _messages_enable: true
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
cordova_payment_validate = ->
cordova_constructor = ->
User = proxyquire('../user', {
  '../../config':
    config_callback: (c)->
      config_callbacks.push c
      c
    module_get: (module)->
      if 'server.authorize' is module
        return {Login, cordova: Cordova, inbox: LoginInbox}
      return {Room, Room2, User}
    config_get: (param)-> config[param]
  '../pubsub/multiserver':
    PubsubModule: class PubsubModule
      constructor: -> PubsubModule_methods.constructor.apply(@, arguments)
      remove: -> PubsubModule_methods.remove.apply(@, arguments)
    PubsubServer: class PubsubServer
      _pubsub: -> _pubsub
  '../api/cordova': class cordova
    constructor: -> cordova_constructor.apply(@, arguments)
    payment_validate: -> cordova_payment_validate.apply(@, arguments)
}).User


describe 'User', ->
  spy = null
  socket = null
  clock = null
  db = {}
  beforeEach ->
    Login::_opt =
      'id': {db: true, public: true}
      'name': {default: '', db: true, public: true}
      'new': {}
      'coins': {}
      'language': {}
      'password': {private: true}
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
      server: 'server'
      cordova:
        id: 'cid'
      ios:
        buy_transaction:
          2: '200m'
        shared_secret: 'shas'
      android:
        email: 'aemail'
        key: 'appkey'
        buy_transaction:
          3: '300m'
          11: 'vip5'
      buy:
        product:
          '1': 50
          '3': 100
        subscription:
          '11': 'vip'
    cordova_constructor = sinon.spy()
    config_callbacks[0]()
    db.select_one = sinon.spy()
    db.insert = sinon.spy()
    db.select = sinon.spy()
    db.replace = sinon.spy()

  afterEach ->
    clock.restore()

  describe 'methods', ->
    user = null
    beforeEach ->
      PubsubModule_methods.constructor = sinon.spy()
      PubsubModule_methods.remove = sinon.spy()
      user = new User({id: 5, socket: socket})
      user.id = 5
      user.emit_module_exec = sinon.spy()

    it 'default options', ->
      user = new User({socket: socket})
      assert(user.options.alive.getTime() <= new Date().getTime())

    it 'cordova options', ->
      assert.equal 1, cordova_constructor.callCount
      assert.deepEqual {email: 'aemail', key: 'appkey', packageName: 'cid'}, cordova_constructor.getCall(0).args[0].android
      assert.deepEqual {shared_secret: 'shas'}, cordova_constructor.getCall(0).args[0].ios

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
      user = new User({id: 5, name: 'b', new: true, password: '124', socket: socket})
      assert.deepEqual({id: 5, name: 'b', new: true}, user.data())

    it 'data public', ->
      user = new User({id: 5, name: 'b', new: true, socket: socket})
      assert.deepEqual({id: 5, name: 'b'}, user.data_public())

    it 'data room', ->
      user.data_public = sinon.fake.returns {id: 2}
      assert.deepEqual({id: 2}, user.data_room())
      assert.equal 1, user.data_public.callCount

    it '_room_add', ->
      assert.notEqual(1, user.room)
      user.lobby = 'lob'
      user.publish = sinon.spy()
      user._room_add(1)
      assert.equal(1, user.room)
      assert.equal(1, user.publish.callCount)
      assert.equal('room:add', user.publish.getCall(0).args[0])
      assert.equal(1, user.publish.getCall(0).args[1])
      assert.equal null, user.lobby

    it 'room remove', ->
      user.publish = sinon.spy()
      user.room = 1
      user._room_remove()
      assert.notEqual(1, user.room)
      assert.equal(1, user.publish.callCount)
      assert.equal('room:remove', user.publish.getCall(0).args[0])
      assert.equal(1, user.publish.getCall(0).args[1])

    it 'room remove (null)', ->
      user.publish = sinon.spy()
      user.room = null
      user._room_remove()
      assert.equal 0, user.publish.callCount

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

    it '_room_update (room not defined)', ->
      user.publish = sinon.spy()
      user.room = null
      user._room_update({ben: 'room'})
      assert.equal null, user.room
      assert.equal(0, user.publish.callCount)

    it '_rooms_master_exe', ->
      user.data_room = sinon.fake.returns({id: 5})
      user._rooms_master_exe( '_add', 'roo', {p: 'r'} )
      assert.equal(1, _pubsub.emit_server_master_exec.callCount)
      assert.equal('roo', _pubsub.emit_server_master_exec.getCall(0).args[0])
      assert.equal('_add', _pubsub.emit_server_master_exec.getCall(0).args[1])
      assert.deepEqual({id: 5}, _pubsub.emit_server_master_exec.getCall(0).args[2])
      assert.deepEqual({p: 'r'}, _pubsub.emit_server_master_exec.getCall(0).args[3])
      assert.equal(1, user.data_room.callCount)

    it '_rooms_master_exe (def)', ->
      user.data_room = sinon.fake.returns({})
      user._rooms_master_exe( '_add')
      assert.equal('rooms', _pubsub.emit_server_master_exec.getCall(0).args[0])
      assert.deepEqual({}, _pubsub.emit_server_master_exec.getCall(0).args[3])


    describe 'config (buy params)', ->
      complete = null
      spy = null
      params = null
      beforeEach ->
        User::_buy_params =
          coins:
            type: 8
            service: ['1', '2']
          subscription: {'vip': 'limit'}
        config_callbacks[0]()
        User::emit_self_exec = spy = sinon.spy()
        complete = sinon.spy()
        params =
          user_id: 5
          transaction: {id: 56, service: '1'}
          complete: complete

      it 'default', ->
        User::_buy_callback(params)
        assert.equal 1, spy.callCount
        assert.equal 5, spy.getCall(0).args[0]
        assert.equal 'set_coins', spy.getCall(0).args[1]
        assert.deepEqual {type: 8, coins: 50}, spy.getCall(0).args[2]
        spy.getCall(0).args[3]()
        assert.equal 1, complete.callCount

      it 'not in coins', ->
        params.transaction.service = '3'
        User::_buy_callback(params)
        assert.equal 'set_product', spy.getCall(0).args[1]
        assert.deepEqual {transaction: {id: 56, service: '3', value: 100}}, spy.getCall(0).args[2]

      it 'subscription', ->
        params.transaction.service = '11'
        User::_buy_callback(params)
        assert.equal 'set_subscription', spy.getCall(0).args[1]
        assert.deepEqual {field: 'limit', expire: 32}, spy.getCall(0).args[2]

      it 'subscription (expire)', ->
        params.transaction.service = '11'
        params.transaction.expire = 5
        User::_buy_callback(params)
        assert.equal 'set_subscription', spy.getCall(0).args[1]
        assert.equal 5, spy.getCall(0).args[2].expire


    describe 'rooms_master', ->
      beforeEach ->
        user._rooms_master_exe = sinon.spy()

      it 'rooms_lobby_add', ->
        user.rooms_lobby_add()
        assert.equal 1, user._rooms_master_exe.callCount
        assert.equal 'lobby_add', user._rooms_master_exe.getCall(0).args[0]
        assert.equal 'rooms', user._rooms_master_exe.getCall(0).args[1]
        assert.deepEqual {}, user._rooms_master_exe.getCall(0).args[2]

      it 'rooms_lobby_add (params)', ->
        user.rooms_lobby_add('ro', {p: 'a'})
        assert.equal 'ro', user._rooms_master_exe.getCall(0).args[1]
        assert.deepEqual {p: 'a'}, user._rooms_master_exe.getCall(0).args[2]

      it 'rooms_lobby_remove', ->
        user.lobby = {module: 'rooms'}
        user.rooms_lobby_remove()
        assert.equal 1, user._rooms_master_exe.callCount
        assert.equal 'lobby_remove', user._rooms_master_exe.getCall(0).args[0]
        assert.equal 'rooms', user._rooms_master_exe.getCall(0).args[1]

      it 'rooms_lobby_remove (no lobby)', ->
        user.rooms_lobby_remove('ro')
        assert.equal 0, user._rooms_master_exe.callCount


    it 'rooms_reconnect', ->
      user.id = 5
      user.rooms_reconnect()
      assert.equal(1, _pubsub.emit_all_exec.callCount)
      assert.equal('rooms', _pubsub.emit_all_exec.getCall(0).args[0])
      assert.equal('_objects_exec', _pubsub.emit_all_exec.getCall(0).args[1])
      assert.deepEqual({user_reconnect: 5}, _pubsub.emit_all_exec.getCall(0).args[2])

    it 'rooms_reconnect (params)', ->
      user.rooms_reconnect('tours', 'fn')
      assert.equal('tours', _pubsub.emit_all_exec.getCall(0).args[0])
      assert.equal('fn', _pubsub.emit_all_exec.getCall(0).args[3])

    it '_lobby_add', ->
      user.publish = sinon.spy()
      user._lobby_add({p: 'a'})
      assert.equal(1, user.publish.callCount)
      assert.equal('lobby:add', user.publish.getCall(0).args[0])
      assert.deepEqual({p: 'a'}, user.publish.getCall(0).args[1])
      assert.deepEqual {p: 'a'}, user.lobby

    it '_lobby_remove', ->
      user.lobby = {l: 'bo'}
      user.publish = sinon.spy()
      user._lobby_remove({p: 'a'})
      assert.equal(1, user.publish.callCount)
      assert.equal('lobby:remove', user.publish.getCall(0).args[0])
      assert.deepEqual({l: 'bo'}, user.publish.getCall(0).args[1])
      assert.equal null, user.lobby

    it 'remove user', ->
      user.room_exec = sinon.spy()
      PubsubModule_methods.remove = sinon.spy()
      user.options.socket.disconnect = sinon.spy()
      user.remove()
      assert.equal(1, PubsubModule_methods.remove.callCount)
      assert.equal(1, user.room_exec.callCount)
      assert.equal('user_remove', user.room_exec.getCall(0).args[0])
      assert.deepEqual({id: 5, disconnect: true}, user.room_exec.getCall(0).args[1])
      assert.equal(1, user.options.socket.disconnect.callCount)
      assert.equal(null, user.options.socket.disconnect.getCall(0).args[0])

    it 'remove user (duplicate)', ->
      user.room_exec = sinon.spy()
      user.options.socket.disconnect = sinon.spy()
      user.remove('duplicate')
      assert.equal('duplicate', user.options.socket.disconnect.getCall(0).args[0])

    it 'remove user (2 times)', ->
      user.room_exec = sinon.spy()
      user.options.socket.disconnect = sinon.spy()
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
      assert.equal('alive', user.options.alive)

    it 'set (socket)', ->
      user._bind_socket = sinon.spy()
      user.set({socket: 's'})
      assert.equal(1, user._bind_socket.callCount)

    it 'set (publish)', ->
      user.publish = sinon.spy()
      user.set({new: true})
      assert.equal(1, user.publish.callCount)
      assert.equal('user:update', user.publish.getCall(0).args[0])
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
      user._set_coins_db {user_id: 1, type: 2, coins: 5}, spy
      assert.equal 1, db.insert.callCount
      assert.equal 'coins_history', db.insert.getCall(0).args[0].table
      assert.deepEqual {user_id: 1, action: new Date(), type: 2, coins: 5}, db.insert.getCall(0).args[0].data
      db.insert.getCall(0).args[1]()
      assert.equal 1, spy.callCount

    it '_set_coins_db (no callback)', ->
      user._set_coins_db {user_id: 1, type: 2, coins: 5}
      assert.doesNotThrow -> db.insert.getCall(0).args[1]()

    it 'set_coins', ->
      user.options.coins_history = [{coins: 2}]
      user.set = sinon.spy()
      user._set_coins_db = sinon.spy()
      user.options.coins = 10
      user.set_coins {type: 2, coins: 5}, 'cl'
      assert.equal 1, user.set.callCount
      assert.deepEqual {coins: 15}, user.set.getCall(0).args[0]
      assert.equal 1, user._set_coins_db.callCount
      assert.deepEqual {user_id: 5, type: 2, coins: 5}, user._set_coins_db.getCall(0).args[0]
      assert.equal 'cl', user._set_coins_db.getCall(0).args[1]
      assert.deepEqual [{action: new Date(), type: 2, coins: 5}, {coins: 2}], user.options.coins_history

    it 'set_coins (no history)', ->
      user.set = ->
      user._set_coins_db = ->
      user.options.coins = 10
      user.set_coins {type: 2, coins: 5}
      assert.ok !user.options.coins_history?

    it 'set_coins (ifoffline)', ->
      user._set_db = sinon.spy()
      user._set_coins_db = sinon.spy()
      user.set_coins_ifoffline 2, {type: 2, coins: 5}
      assert.equal 1, user._set_coins_db.callCount
      assert.deepEqual {user_id: 2, type: 2, coins: 5}, user._set_coins_db.getCall(0).args[0]
      assert.equal 1, user._set_db.callCount
      assert.deepEqual {id: 2, coins: {increase: 5}}, user._set_db.getCall(0).args[0]

    it 'set_subscription', ->
      user.set = sinon.spy()
      user.set_subscription({field: 'limit', expire: 31})
      assert.equal 1, user.set.callCount
      assert.deepEqual {limit: 31}, user.set.getCall(0).args[0]

    it 'set_subscription_ifoffline', ->
      user._set_db = sinon.spy()
      user.set_subscription_ifoffline 5, {field: 'limit', expire: 30}
      assert.equal 1, user._set_db.callCount
      assert.deepEqual {id: 5, limit: 30}, user._set_db.getCall(0).args[0]

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


    describe 'User message', ->
      date_joined = null
      now = null
      beforeEach ->
        now = new Date()
        date_joined = new Date(new Date().getTime() - 1000)
        user.options.date_joined = date_joined
        user.set = sinon.spy()
        socket.on = sinon.spy()
        user.options.messages = [{id: 8, message: 'm8'}, {id: 9}]
        user.publish = sinon.spy()

      it 'default', ->
        assert.deepEqual {table: 'user_message', limit: 10, language: null}, user._message

      it 'messages', ->
        user._message_check()
        assert.equal 1, db.select.callCount
        assert.deepEqual ['id', 'user_id', 'added', 'message'], db.select.getCall(0).args[0].select
        assert.equal 'user_message', db.select.getCall(0).args[0].table
        assert.equal 10, db.select.getCall(0).args[0].limit
        assert.deepEqual ['-added'], db.select.getCall(0).args[0].order
        assert.deepEqual {
          user_id: [5, null]
          added: {sign: ['>', date_joined]}
          actual: [null, {sign: ['>', now] }]
          platform: null
        }, db.select.getCall(0).args[0].where
        db.select.getCall(0).args[1]([
          {id: 5, added: new Date(new Date().getTime() + 1000 * 60 + 550 ), message: '<h1>1234</h1> 1234567890 1234567890' }
          {id: 6, added: new Date(new Date().getTime() + 1000 * 40 + 450), message: 'm2'  }
        ])
        assert.equal 2, db.select.callCount
        assert.deepEqual ['user_message_id'], db.select.getCall(1).args[0].select
        assert.equal 'user_message_read', db.select.getCall(1).args[0].table
        assert.deepEqual {user_id: 5, user_message_id: [5, 6]}, db.select.getCall(1).args[0].where
        db.select.getCall(1).args[1]([ {user_message_id: 6} ])
        assert.equal 1, user.set.callCount
        assert.deepEqual {messages: [ {id: 5, intro: '1234 1234567890', added: 61}, {id: 6, added: 40, intro: 'm2', read: true} ] }, user.set.getCall(0).args[0]

      it 'messages with platform', ->
        user.options.platform = 'draugiem'
        user._message_check()
        assert.deepEqual [null, {json: 'draugiem'}], db.select.getCall(0).args[0].where.platform

      it 'messages with language', ->
        user.options.language = 'lv'
        user._message.language = true
        user._message_check()
        assert.deepEqual [null, {json: 'lv'}], db.select.getCall(0).args[0].where.language

      it 'no messages', ->
        user._message_check()
        db.select.getCall(0).args[1]([])
        assert.equal 1, db.select.callCount

      it 'read', ->
        user._message_check()
        assert.equal 1, socket.on.callCount
        assert.equal 'user:message', socket.on.getCall(0).args[0]
        socket.on.getCall(0).args[1]({id: 9})
        assert.equal 1, db.select_one.callCount
        assert.deepEqual ['message'], db.select_one.getCall(0).args[0].select
        assert.equal 'user_message', db.select_one.getCall(0).args[0].table
        assert.deepEqual {id: 9}, db.select_one.getCall(0).args[0].where
        db.select_one.getCall(0).args[1]({message: 'm9'})
        assert.equal 1, user.publish.callCount
        assert.equal 'user:message', user.publish.getCall(0).args[0]
        assert.deepEqual {id: 9, message: 'm9', read: true}, user.publish.getCall(0).args[1]
        assert.equal 1, db.insert.callCount
        assert.equal 'user_message_read', db.insert.getCall(0).args[0].table
        assert.deepEqual {user_message_id: 9, user_id: 5, added: new Date()}, db.insert.getCall(0).args[0].data

      it 'read not found on db', ->
        user._message_check()
        socket.on.getCall(0).args[1]({id: 9})
        db.select_one.getCall(0).args[1](null)
        assert.equal 0, user.publish.callCount

      it 'message preloaded', ->
        user._message_check()
        socket.on.getCall(0).args[1]({id: 8})
        assert.equal 1, user.publish.callCount
        assert.deepEqual {id: 8, message: 'm8'}, user.publish.getCall(0).args[1]

      it 'id not found', ->
        user._message_check()
        socket.on.getCall(0).args[1]({id: 10})
        assert.equal 0, db.select_one.callCount
        assert.equal 0, user.publish.callCount

      it 'no params', ->
        user._message_check()
        socket.on.getCall(0).args[1]()
        assert.equal 0, db.select_one.callCount
        assert.equal 0, user.publish.callCount


  describe 'User events', ->
    user = null
    socket = null
    beforeEach ->
      socket = new SimpleEvent()
      socket.send = sinon.spy()
      user = new User({id: 5, socket: socket, language: 'en', api: {buy: sinon.spy(), buy_validate: sinon.spy()}})
      user.room = {id: 3, module: 'Room'}
      user.room_exec = sinon.spy()

    it 'alive', ->
      clock.tick(10 * 1000)
      socket.emit 'alive'
      assert.equal(user.get('alive').getTime(), new Date().getTime())

    it 'user:update', ->
      Login::_opt.language.validate = -> 'en'
      Login::_opt.name.validate = -> 'mi'
      Login::_opt.coins.validate = -> 3
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


    describe 'bind message', ->
      fn = null
      beforeEach ->
        fn = (m)-> socket.emit 'message:add', m
        user.room_exec = sinon.spy()
        user.id = 5
        user.room = {id: 1, module: 'Room'}

      it 'default', ->
        fn('m1')
        assert.equal 1, user.room_exec.callCount
        assert.equal '_message_add', user.room_exec.getCall(0).args[0]
        assert.deepEqual {user_id: 5, message: 'm1'}, user.room_exec.getCall(0).args[1]

      it 'messages disabled', ->
        user.room.module = 'Room2'
        fn('m1')
        assert.equal 0, user.room_exec.callCount

      it 'no room', ->
        user.room = null
        fn('m1')
        assert.equal 0, user.room_exec.callCount

      it 'no message', ->
        fn()
        assert.equal 0, user.room_exec.callCount

      it 'other type', ->
        fn({})
        assert.equal 0, user.room_exec.callCount


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
      action = new Date(new Date().getTime() - 1550)
      db.select.getCall(0).args[1]([{coins: 5, action}])
      assert.deepEqual [{coins: 5, action}], user.options.coins_history
      assert.equal 1, user.publish.callCount
      assert.equal 'coins:history', user.publish.getCall(0).args[0]
      assert.deepEqual [{coins: 5, action, action_seconds: -2}], user.publish.getCall(0).args[1]

    it '_bind_socket_coins_history (fetched)', ->
      db.select = sinon.spy()
      user.id = 5
      user.publish = sinon.spy()
      user.options.coins_history = []
      user._bind_socket_coins_history()
      socket.emit 'coins:history'
      assert.equal 0, db.select.callCount
      assert.deepEqual [], user.publish.getCall(0).args[1]

    it '_bind_socket_cordova', ->
      user.id = 5
      user._bind_socket_cordova()
      socket.emit 'user:update:cordova', {token: 'tkn'}
      assert.equal 1, db.replace.callCount
      assert.equal 'auth_user_cordova_params', db.replace.getCall(0).args[0].table
      assert.deepEqual ['user_id'], db.replace.getCall(0).args[0].unique
      assert.deepEqual {user_id: 5, token: 'tkn', last_updated: new Date()}, db.replace.getCall(0).args[0].data

    it '_bind_socket_cordova (no token)', ->
      user._bind_socket_cordova()
      socket.emit 'user:update:cordova'
      assert.equal 0, db.replace.callCount


    describe '_bind_socket_coins_buy', ->
      buy_complete = null
      buy_inbox = null
      beforeEach ->
        db.select = sinon.spy()
        user.id = 5
        user.publish = sinon.spy()
        buy_inbox = sinon.spy()
        LoginInbox::buy = -> buy_inbox.apply(@, arguments)
        buy_complete = sinon.spy()
        Cordova::buy_complete = -> buy_complete.apply(@, arguments)
        user._buy_callback = sinon.spy()
        cordova_payment_validate = sinon.spy()

      it 'facebook', ->
        user.options.api._name = 'facebook'
        user._bind_socket_coins_buy()
        socket.emit 'buy:facebook', { service: 2, language: 'rp' }
        assert.equal 1, user.options.api.buy.callCount
        assert.deepEqual {service: 2, user_id: 5, language: 'rp'} , user.options.api.buy.getCall(0).args[0]
        user.options.api.buy.getCall(0).args[1]({id: 10})
        assert.equal 'buy:facebook', user.publish.getCall(0).args[0]
        assert.deepEqual {service: 2, id: 10}, user.publish.getCall(0).args[1]

      it 'no params', ->
        user.options.api._name = 'facebook'
        user._bind_socket_coins_buy()
        socket.emit 'buy:facebook'
        assert.equal 0, user.options.api.buy.callCount

      it 'draugiem', ->
        user.options.api._name = 'draugiem'
        user._bind_socket_coins_buy()
        socket.emit 'buy:draugiem', { service: 2 }
        user.options.api.buy.getCall(0).args[1]({id: 10})
        assert.equal 'buy:draugiem', user.publish.getCall(0).args[0]

      it 'inbox', ->
        user.options.api._name = 'inbox'
        user._bind_socket_coins_buy()
        socket.emit 'buy:inbox', {service: 2}
        user.options.api.buy.getCall(0).args[1]({id: 10})
        assert.equal 'buy:inbox', user.publish.getCall(0).args[0]

      it 'odnoklassniki', ->
        user.options.api._name = 'odnoklassniki'
        user._bind_socket_coins_buy(['odnoklassniki'])
        socket.emit 'buy:odnoklassniki', {service: 2}
        user.options.api.buy.getCall(0).args[1]({id: 10})
        assert.equal 'buy:odnoklassniki', user.publish.getCall(0).args[0]

      it 'yandex', ->
        user.options.api._name = 'yandex'
        user._bind_socket_coins_buy(['yandex'])
        socket.emit 'buy:yandex', {service: 2}
        user.options.api.buy.getCall(0).args[1]({id: 10})
        assert.equal 'buy:yandex', user.publish.getCall(0).args[0]

      it 'not included', ->
        user.options.api._name = 'inbox'
        user._bind_socket_coins_buy(['facebook'])
        socket.emit 'buy:inbox', {service: 2}
        assert.equal 0, user.options.api.buy.callCount

      it 'unexisting', ->
        user.options.api._name = 'boom'
        user._bind_socket_coins_buy()
        socket.emit 'buy:inbox', {service: 2}
        socket.emit 'buy:boom', {service: 2}
        assert.equal 0, user.options.api.buy.callCount

      it 'inbox_standalone', ->
        user._bind_socket_coins_buy(['inbox_standalone'])
        socket.emit 'buy:inbox_standalone', {service: 2, language: 'lg'}
        assert.equal 1, buy_inbox.callCount
        assert.deepEqual {service: 2, user_id: 5, language: 'lg'}, buy_inbox.getCall(0).args[0]
        buy_inbox.getCall(0).args[1]({id: 10})
        assert.equal 'buy:inbox_standalone', user.publish.getCall(0).args[0]
        assert.deepEqual {id: 10, service: 2}, user.publish.getCall(0).args[1]

      it 'inbox_standalone (no args)', ->
        user._bind_socket_coins_buy(['inbox_standalone'])
        socket.emit 'buy:inbox_standalone'
        assert.equal 0, buy_inbox.callCount

      it 'inbox_standalone (unexist)', ->
        user._bind_socket_coins_buy(['inbox_other'])
        socket.emit 'buy:inbox_standalone', {service: 2, language: 'lg'}
        assert.equal 0, buy_inbox.callCount

      it 'cordova ios', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, platform: 'ios', transaction: 'tr' }
        assert.equal 1, cordova_payment_validate.callCount
        assert.deepEqual {transaction: 'tr', platform: 'ios'}, cordova_payment_validate.getCall(0).args[0]
        cordova_payment_validate.getCall(0).args[1](null, {platform: 'ios', product_id: '200m', transaction_id: 'trid', expire: 1000 * 60 * 60 * 26})
        assert.equal 1, buy_complete.callCount
        assert.deepEqual {user_id: 5, service: '2', transaction_id: 'trid', platform: 'ios'}, buy_complete.getCall(0).args[0]
        buy_complete.getCall(0).args[1]({p: 'ram', transaction: {service: '1'}})
        assert.equal 1, user._buy_callback.callCount
        assert.deepEqual {p: 'ram', transaction: {service: '1', expire: 2}, platform: 'ios'}, user._buy_callback.getCall(0).args[0]
        buy_complete.getCall(0).args[2]()
        assert.equal 1, user.publish.callCount
        assert.equal 'buy:cordova:finish', user.publish.getCall(0).args[0]
        assert.deepEqual {id_local: 0}, user.publish.getCall(0).args[1]

      it 'cordova ios (product_id null)', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, platform: 'ios', transaction: 'tr', product_id: 'cid' }
        cordova_payment_validate.getCall(0).args[1](null, {platform: 'ios', product_id: null})
        assert.equal 0, buy_complete.callCount
        assert.equal 1, user.publish.callCount
        assert.equal 'buy:cordova:finish', user.publish.getCall(0).args[0]
        assert.deepEqual {id_local: 0}, user.publish.getCall(0).args[1]

      it 'cordova ios (product_id null) app not match', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, platform: 'ios', transaction: 'tr', product_id: 'cidother' }
        cordova_payment_validate.getCall(0).args[1](null, {platform: 'ios', product_id: null})
        assert.equal 0, buy_complete.callCount
        assert.equal 0, user.publish.callCount

      it 'cordova ios (complete error)', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, platform: 'ios', transaction: 'tr' }
        cordova_payment_validate.getCall(0).args[1](null, {platform: 'ios', product_id: '200m', transaction_id: 'trid', expire: 1000 * 60 * 60 * 26})
        buy_complete.getCall(0).args[2]('err')
        assert.equal 0, user.publish.callCount

      it 'cordova ios (complete error: transaction already completed)', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, platform: 'ios', transaction: 'tr' }
        cordova_payment_validate.getCall(0).args[1](null, {platform: 'ios', product_id: '200m', transaction_id: 'trid', expire: 1000 * 60 * 60 * 26})
        buy_complete.getCall(0).args[2]('transaction already completed')
        assert.equal 1, user.publish.callCount

      it 'cordova ios expire not exist', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, platform: 'ios', transaction: 'tr' }
        cordova_payment_validate.getCall(0).args[1](null, {platform: 'ios', product_id: '200m', transaction_id: 'trid', expire: null})
        buy_complete.getCall(0).args[1]({transaction: {}})
        assert.equal null, user._buy_callback.getCall(0).args[0].transaction.expire

      it 'cordova ios service not found', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, platform: 'ios', transaction: 'tr' }
        cordova_payment_validate.getCall(0).args[1](null, {platform: 'ios', product_id: '300m', expire: 12})
        assert.equal 0, buy_complete.callCount

      it 'cordova ios (buy error)', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, platform: 'ios', transaction: 'tr' }
        cordova_payment_validate.getCall(0).args[1]('err')
        assert.equal 0, buy_complete.callCount

      it 'cordova android', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, product_id: '300m', platform: 'android', transaction: 'tr' }
        assert.deepEqual {transaction: 'tr', product_id: '300m', platform: 'android', subscription: false}, cordova_payment_validate.getCall(0).args[0]

      it 'cordova android subscription', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, product_id: 'vip5', platform: 'android', transaction: 'tr' }
        assert.equal true, cordova_payment_validate.getCall(0).args[0].subscription

      it 'cordova android subscription (config subscription emtpy)', ->
        delete config.buy.subscription
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, product_id: 'vip5', platform: 'android', transaction: 'tr' }
        assert.equal false, cordova_payment_validate.getCall(0).args[0].subscription

      it 'cordova android no product', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova', {id_local: 0, product_id: 'novip', platform: 'android', transaction: 'tr' }
        assert.equal 0, cordova_payment_validate.callCount

      it 'cordova no params', ->
        user._bind_socket_coins_buy(['cordova'])
        socket.emit 'buy:cordova'
        socket.emit 'buy:cordova', {id_local: 0, product_id: '200m', platform: 'windows', transaction: 'tr' }
        socket.emit 'buy:cordova', {id_local: 2, platform: 'ios'}
        socket.emit 'buy:cordova', {id_local: 2, platform: 'android', transaction: 'tr'}
        assert.equal 0, cordova_payment_validate.callCount

      it 'cordova unexists', ->
        user._bind_socket_coins_buy(['cordovas'])
        socket.emit 'buy:cordova', {id_local: 0, platform: 'ios', transaction: 'tr' }
        assert.equal 0, cordova_payment_validate.callCount


      describe 'validate', ->

        describe 'yandex', ->
          beforeEach ->
            user.options.api._name = 'yandex'
            user._bind_socket_coins_buy(['yandex'])


          it 'default', ->
            socket.emit 'buy:yandex:validate', {signature: 'sig', id_local: 2}
            assert.equal 1, user.options.api.buy_validate.callCount
            assert.deepEqual {signature: 'sig', user_id: 5}, user.options.api.buy_validate.getCall(0).args[0]
            user.options.api.buy_validate.getCall(0).args[1]({'pa': 'ram'})
            assert.equal 1, user._buy_callback.callCount
            assert.deepEqual {pa: 'ram', platform: 'yandex'}, user._buy_callback.getCall(0).args[0]
            user.options.api.buy_validate.getCall(0).args[2]()
            assert.equal 1, user._buy_callback.callCount
            assert.equal 1, user.publish.callCount
            assert.equal 'buy:yandex:validate', user.publish.getCall(0).args[0]
            assert.deepEqual {signature: 'sig', id_local: 2}, user.publish.getCall(0).args[1]

          it 'no params', ->
            socket.emit 'buy:yandex:validate', null
            socket.emit 'buy:yandex:validate', {no: 'signature'}
            assert.equal 0, user.options.api.buy_validate.callCount

          it 'validate error', ->
            socket.emit 'buy:yandex:validate', {signature: 'sig', id_local: 2}
            user.options.api.buy_validate.getCall(0).args[2]('err')
            assert.equal 0, user.publish.callCount

          it 'validate transaction completed', ->
            socket.emit 'buy:yandex:validate', {signature: 'sig', id_local: 2}
            user.options.api.buy_validate.getCall(0).args[2]('transaction already completed')
            assert.equal 1, user.publish.callCount
            assert.equal 'buy:yandex:validate', user.publish.getCall(0).args[0]
            assert.deepEqual {signature: 'sig', id_local: 2}, user.publish.getCall(0).args[1]


  describe 'deletion account', ->
    user = null
    api = null
    beforeEach ->
      api =
        deletion_check: sinon.spy()
        deletion_init: sinon.spy()
      config.deletion_url = '/del'
      config_callbacks[0]()
      user = new User({id: 5, socket: socket, api})
      api.deletion_check = sinon.spy()
      api.deletion_init = sinon.spy()
      user.publish = sinon.spy()
      socket.on = sinon.spy()

    it 'constructor', ->
      class UserC extends User
        _bind_socket_deletion: -> spy()

      new UserC({id: 1, socket})
      assert.equal 1, spy.callCount

    it 'default', ->
      user._bind_socket_deletion()
      assert.equal 1, api.deletion_check.callCount
      assert.deepEqual {user_id: 5}, api.deletion_check.getCall(0).args[0]
      api.deletion_check.getCall(0).args[1]({status: 'Initiated', code: 'cd'})
      assert.equal 1, user.publish.callCount
      assert.equal 'user:deletion:status', user.publish.getCall(0).args[0]
      assert.deepEqual {status: 'Initiated', url: 'server/del/cd'}, user.publish.getCall(0).args[1]

    it 'no status', ->
      user._bind_socket_deletion()
      api.deletion_check.getCall(0).args[1](null)
      assert.equal 0, user.publish.callCount

    it 'init', ->
      user._bind_socket_deletion()
      assert.equal 1, socket.on.callCount
      assert.equal 'user:deletion:init', socket.on.getCall(0).args[0]
      socket.on.getCall(0).args[1]()
      assert.equal 1, api.deletion_init.callCount
      assert.deepEqual {user_id: 5}, api.deletion_init.getCall(0).args[0]
      api.deletion_init.getCall(0).args[1]({status: 'Initiated', code: 'cd2'})
      assert.equal 1, user.publish.callCount
      assert.equal 'user:deletion:status', user.publish.getCall(0).args[0]
      assert.deepEqual {status: 'Initiated', url: 'server/del/cd2'}, user.publish.getCall(0).args[1]

    it 'no deletion url', ->
      config.deletion_url = null
      config_callbacks[0]()
      user._bind_socket_deletion()
      assert.equal 0, api.deletion_check.callCount
      assert.equal 0, socket.on.callCount


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
      assert.deepEqual ['action', 'coins'], db.select_one.getCall(0).args[0].select
      assert.equal 'coins_history', db.select_one.getCall(0).args[0].table
      assert.deepEqual {user_id: 5, type: 1}, db.select_one.getCall(0).args[0].where
      assert.deepEqual ['-action'], db.select_one.getCall(0).args[0].order
      d = new Date()
      d.setSeconds(d.getMinutes() - 60 * 60)
      config.db.select_one.getCall(0).args[1]({action: d})
      assert.equal(1, spy.callCount)
      assert.deepEqual {left: 60 * 60 * 7, coins: 150}, spy.getCall(0).args[0]

    it '__coins_bonus_check (share)', ->
      user.__coins_bonus_check 'share', spy
      assert.equal 3, db.select_one.getCall(0).args[0].where.type
      d = new Date()
      d.setSeconds(d.getMinutes() - 60 * 60)
      config.db.select_one.getCall(0).args[1]({action: d})
      assert.equal 60 * 60 * 9, spy.getCall(0).args[0].left

    it '__coins_bonus_check (passed)', ->
      user.__coins_bonus_check 'daily', spy
      d = new Date()
      d.setSeconds(d.getMinutes() - 60 * 60 * 10)
      config.db.select_one.getCall(0).args[1]({action: d})
      assert.equal 0, spy.getCall(0).args[0].left

    it '__coins_bonus_check (no entries)', ->
      clock.tick 30 * 24 * 60 * 60 * 1000
      user.__coins_bonus_check 'daily', spy
      config.db.select_one.getCall(0).args[1](null)
      assert.equal 0, spy.getCall(0).args[0].left

    it '__coins_bonus_check (coins fn)', ->
      user._coins_bonus_params['daily'].coins = coins = sinon.fake -> {coins: 6, 'p': 'a'}
      user.__coins_bonus_check 'daily', spy
      d = new Date()
      d.setSeconds(d.getMinutes() - 60 * 60 * 10)
      config.db.select_one.getCall(0).args[1]({action: d, coins: 5})
      assert.deepEqual {coins: 6, 'p': 'a', left: 0}, spy.getCall(0).args[0]
      assert.equal 1, coins.callCount
      assert.deepEqual {left: -60 * 60 * 2, coins: 5, action: d}, coins.getCall(0).args[0]

    it '__coins_bonus_check (coins fn no entries)', ->
      user._coins_bonus_params['daily'].coins = coins = sinon.fake -> {coins: 6, 'p': 'a'}
      user.__coins_bonus_check 'daily', spy
      config.db.select_one.getCall(0).args[1](null)
      assert.deepEqual {left: 60 * 60 * 8}, coins.getCall(0).args[0]


    describe '_coins_bonus', ->
      beforeEach ->
        user.__coins_bonus_check = sinon.spy()
        user.publish = sinon.spy()
        user.set_coins = sinon.spy()
        socket.on = sinon.spy()
        user._coins_bonus('daily')
        user.parent =
          emit_immediate_exec: sinon.spy()

      it 'bind', ->
        assert.equal(1, socket.on.callCount)
        assert.equal('coins:bonus:daily', socket.on.getCall(0).args[0])
        user.__coins_bonus_check = sinon.spy()
        socket.on.getCall(0).args[1]()
        assert.equal 1, user.__coins_bonus_check.callCount
        assert.equal 'daily', user.__coins_bonus_check.getCall(0).args[0]
        user.__coins_bonus_check.getCall(0).args[1]({left: 0, coins: 3})
        assert.equal 1, user.set_coins.callCount
        assert.deepEqual {type: 1, coins: 3}, user.set_coins.getCall(0).args[0]
        user.set_coins.getCall(0).args[1]()
        assert.equal 2, user.__coins_bonus_check.callCount
        user.publish = sinon.spy()
        user.__coins_bonus_check.getCall(1).args[1]({left: 10})
        user.set_coins.getCall(0).args[0]
        assert.deepEqual {reset: true, left: 10}, user.publish.getCall(0).args[1]
        assert.equal 1, user.parent.emit_immediate_exec.callCount
        assert.equal 'emit', user.parent.emit_immediate_exec.getCall(0).args[0]
        assert.equal 'delayed', user.parent.emit_immediate_exec.getCall(0).args[1]
        assert.deepEqual {user_id: 5, event: 'coins:bonus:daily', params: {left: 10, reset: true}}, user.parent.emit_immediate_exec.getCall(0).args[2]

      it 'bind (left not zero)', ->
        user.__coins_bonus_check = sinon.spy()
        socket.on.getCall(0).args[1]()
        user.__coins_bonus_check.getCall(0).args[1]({left: 1, coins: 3})
        assert.equal 0, user.set_coins.callCount
        user.publish = sinon.spy()
        user.__coins_bonus_check.getCall(1).args[1]({left: 10})
        assert.deepEqual {left: 10}, user.publish.getCall(0).args[1]

      it 'publish', ->
        assert.equal 1, user.__coins_bonus_check.callCount
        assert.equal 'daily', user.__coins_bonus_check.getCall(0).args[0]
        user.__coins_bonus_check.getCall(0).args[1]({p: 'ar'})
        assert.equal 1, user.publish.callCount
        assert.equal 'coins:bonus:daily', user.publish.getCall(0).args[0]
        assert.deepEqual {p: 'ar'}, user.publish.getCall(0).args[1]
