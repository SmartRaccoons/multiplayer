SimpleEvent = require('simple.event').SimpleEvent
events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


PubsubModule_methods =
  constructor: ->
  remove: ->

Test_authorize = {}
class TestAuthorize
  authorize: ->
    Test_authorize.apply(@, arguments)

class TestAuthorizeDraugiem extends TestAuthorize
  authorize: ->
    super ...arguments
    @api = 'auth'

class TestAuthorizeFacebook extends TestAuthorize
  authorize: ->
    super ...arguments
    @api = 'auth-face'

dbmemory = {}
locale = {}
params = {draugiem: 'good', facebook: 'good', server_id: 5, dbmemory}
Anonymous = proxyquire '../anonymous',
  './authorize':
    draugiem: TestAuthorizeDraugiem
    facebook: TestAuthorizeFacebook
  '../../config':
    config_get: (p)-> params[p]
    config_callback: (callback)-> callback()
    module_get: -> locale
  '../pubsub/multiserver':
    PubsubModule: class PubsubModule extends SimpleEvent
      constructor: ->
        super()
        PubsubModule_methods.constructor.apply(@, arguments)
      remove: ->
        super()
        PubsubModule_methods.remove.apply(@, arguments)
.Anonymous


describe 'Anonymous', ->
  socket = null
  spy = null
  spy2 = null
  beforeEach ->
    socket = new events.EventEmitter()
    socket.send = sinon.spy()
    spy = sinon.spy()
    spy2 = sinon.spy()
    Test_authorize = sinon.spy()
    dbmemory.random = sinon.spy()
    dbmemory.random_remove = sinon.spy()
    dbmemory.random_get = sinon.spy()
    locale.validate = sinon.fake.returns('en')
    locale.lang_short = sinon.fake.returns('e')

  describe 'common', ->
    anonymous = null
    beforeEach ->
      PubsubModule_methods.constructor = sinon.spy()
      PubsubModule_methods.remove = sinon.spy()
      anonymous = new Anonymous(socket)

    it 'pubsub ', ->
      assert.equal('anonymous', anonymous._module)
      assert.equal(1, PubsubModule_methods.constructor.callCount)
      assert.deepEqual({id: '5:1'}, PubsubModule_methods.constructor.getCall(0).args[0])
      anonymous.remove()
      assert.equal(1, PubsubModule_methods.remove.callCount)

    it 'remove', ->
      anonymous.bind 'remove', spy
      socket.emit 'remove'
      assert.equal(1, spy.callCount)

    it 'remove events', ->
      anonymous.remove()
      anonymous.bind 'remove', spy
      socket.emit 'authenticate:try', null
      assert.equal(0, socket.send.callCount)
      socket.emit 'remove', null
      assert.equal(0, spy.callCount)
      socket.emit 'authenticate:code'
      assert.equal(0, dbmemory.random.callCount)


  describe 'code', ->
    anonymous = null
    beforeEach ->
      anonymous = new Anonymous(socket)
      anonymous._module = 'm'
      anonymous.id = 'id'

    it 'random', ->
      assert.deepEqual([], anonymous._codes)
      socket.emit 'authenticate:code'
      assert.equal(1, locale.validate.callCount)
      assert.equal('', locale.validate.getCall(0).args[0])
      assert.equal(1, locale.lang_short.callCount)
      assert.equal('en', locale.lang_short.getCall(0).args[0])
      assert.equal(1, dbmemory.random.callCount)
      assert.equal('m', dbmemory.random.getCall(0).args[0])
      assert.deepEqual({id: 'id'}, dbmemory.random.getCall(0).args[1])
      dbmemory.random.getCall(0).args[2]({random: 777})
      assert.equal(1, socket.send.callCount)
      assert.equal('authenticate:code', socket.send.getCall(0).args[0])
      assert.deepEqual({random: 'e777'}, socket.send.getCall(0).args[1])
      assert.deepEqual([777], anonymous._codes)

    it 'random (language)', ->
      socket.emit 'authenticate:code', {language: 'lv'}
      assert.equal('lv', locale.validate.getCall(0).args[0])

    it 'check', ->
      socket.emit 'authenticate:code_check', {random: 'r23'}
      assert.equal 1, dbmemory.random_get.callCount
      assert.equal 'm', dbmemory.random_get.getCall(0).args[0]
      assert.equal '23', dbmemory.random_get.getCall(0).args[1]
      anonymous.authenticate = sinon.spy()
      dbmemory.random_get.getCall(0).args[2]({authenticate: 'p'})
      assert.equal 1, anonymous.authenticate.callCount
      assert.equal 'p', anonymous.authenticate.getCall(0).args[0]
      assert.equal 0, socket.send.callCount

    it 'check (no data)', ->
      socket.emit 'authenticate:code_check', {random: 'r23'}
      anonymous.authenticate = sinon.spy()
      dbmemory.random_get.getCall(0).args[2]()
      assert.equal 0, anonymous.authenticate.callCount
      assert.equal 1, socket.send.callCount
      assert.equal 'authenticate:code_error', socket.send.getCall(0).args[0]

    it 'check (no authorize data)', ->
      socket.emit 'authenticate:code_check', {random: 'r23'}
      anonymous.authenticate = sinon.spy()
      dbmemory.random_get.getCall(0).args[2]({s: 'd'})
      assert.equal 0, anonymous.authenticate.callCount
      assert.equal 1, socket.send.callCount

    it 'check (no params)', ->
      socket.emit 'authenticate:code_check'
      assert.equal 0, dbmemory.random_get.callCount
      assert.equal 1, socket.send.callCount


  describe 'Login', ->
    login = null
    anonymous = null
    beforeEach ->
      anonymous = new Anonymous(socket)

    it 'draugiem authenticate', ->
      anonymous.bind 'login', spy
      socket.emit 'authenticate:try', {draugiem: 'cd', language: 'lv', other: 'param', params: 'pr'}
      assert.equal(1, Test_authorize.callCount)
      assert.deepEqual({code: 'cd', language: 'lv', params: 'pr'}, Test_authorize.getCall(0).args[0])
      Test_authorize.getCall(0).args[1]({id: 5})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5}, spy.getCall(0).args[0])
      assert.equal('auth', spy.getCall(0).args[1].api)
      assert.equal('authenticate:params', socket.send.getCall(0).args[0])
      assert.deepEqual({draugiem: 'cd'}, socket.send.getCall(0).args[1])

    it 'draugiem authenticate (error)', ->
      anonymous.bind 'login', spy
      socket.emit 'authenticate:try', {draugiem: 'cd'}
      Test_authorize.getCall(0).args[1](null)
      assert.equal(0, spy.callCount)
      assert.equal(1, socket.send.callCount)
      assert.equal('authenticate:error', socket.send.getCall(0).args[0])

    it 'facebook authenticate', ->
      anonymous.bind 'login', spy
      socket.emit 'authenticate:try', {facebook: 'cd'}
      Test_authorize.getCall(0).args[1]({id: 5})
      assert.equal('auth-face', spy.getCall(0).args[1].api)

    it 'authenticate no class', ->
      socket.emit 'authenticate:try', {codes: 'cd'}
      assert.equal(0, Test_authorize.callCount)
      assert.equal(1, socket.send.callCount)
      assert.equal('authenticate:error', socket.send.getCall(0).args[0])

    it 'authenticate no params', ->
      socket.emit 'authenticate:try', null
      assert.equal(0, Test_authorize.callCount)
      assert.equal(1, socket.send.callCount)
      assert.equal('authenticate:error', socket.send.getCall(0).args[0])
