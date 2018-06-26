events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


Test_authrorize = {}
class TestAuthorize
  authorize: ->
    Test_authrorize.apply(@, arguments)

class TestAuthorizeDraugiem extends TestAuthorize
  authorize: ->
    super
    @api = 'auth'

class TestAuthorizeFacebook extends TestAuthorize
  authorize: ->
    super
    @api = 'auth-face'

params = {draugiem: 'good', facebook: 'good'}
Anonymous = proxyquire '../anonymous',
  './authorize':
    draugiem: TestAuthorizeDraugiem
    facebook: TestAuthorizeFacebook
  '../../config':
    config_get: (p)-> params[p]
    config_callback: (callback)-> callback()
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
    Test_authrorize = sinon.spy()

  describe 'common', ->
    anonymous = null
    beforeEach ->
      anonymous = new Anonymous(socket)

    it 'remove authenticate:try event', ->
      anonymous.remove()
      socket.emit 'authenticate:try', null
      assert.equal(0, socket.send.callCount)


  describe 'Login', ->
    login = null
    anonymous = null
    beforeEach ->
      anonymous = new Anonymous(socket)

    it 'draugiem authenticate', ->
      anonymous.on 'login', spy
      socket.emit 'authenticate:try', {draugiem: 'cd', language: 'lv', other: 'param'}
      assert.equal(1, Test_authrorize.callCount)
      assert.deepEqual({code: 'cd', language: 'lv'}, Test_authrorize.getCall(0).args[0])
      Test_authrorize.getCall(0).args[1]({id: 5})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5}, spy.getCall(0).args[0])
      assert.equal('auth', spy.getCall(0).args[1].api)

    it 'draugiem authenticate (error)', ->
      anonymous.on 'login', spy
      socket.emit 'authenticate:try', {draugiem: 'cd'}
      Test_authrorize.getCall(0).args[1](null)
      assert.equal(0, spy.callCount)
      assert.equal(1, socket.send.callCount)
      assert.equal('authenticate:error', socket.send.getCall(0).args[0])

    it 'facebook authenticate', ->
      anonymous.on 'login', spy
      socket.emit 'authenticate:try', {facebook: 'cd'}
      Test_authrorize.getCall(0).args[1]({id: 5})
      assert.equal('auth-face', spy.getCall(0).args[1].api)

    it 'authenticate no class', ->
      socket.emit 'authenticate:try', {codes: 'cd'}
      assert.equal(0, Test_authrorize.callCount)
      assert.equal(1, socket.send.callCount)
      assert.equal('authenticate:error', socket.send.getCall(0).args[0])

    it 'authenticate no params', ->
      socket.emit 'authenticate:try', null
      assert.equal(0, Test_authrorize.callCount)
      assert.equal(1, socket.send.callCount)
      assert.equal('authenticate:error', socket.send.getCall(0).args[0])
