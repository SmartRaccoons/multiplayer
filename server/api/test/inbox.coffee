assert = require('assert')
sinon = require('sinon')


config =
  inbox:
    dev_id: 'dev id'
    api_key: 'api key'
    application_id: 'app id'
    transaction: '/ibox-url'
    transaction_completed: '/ibox-url-completed-'
  server: 'sr.lv'
Api = require('../inbox').ApiInbox

describe 'api', ->
  spy = null
  a = null
  beforeEach ->
    spy = sinon.spy()
    a = new Api(config)

  describe 'authorize', ->
    beforeEach ->
      a._get_data = (p, data, callback)->
        callback({code: '200 OK',users: [ { apiKey: 'apikey',fname: 'name', lname: 'lname',mail: 'm@openid.inbox.lv', language: 'lg' } ] })

    it 'ok', ->
      spy = sinon.spy()
      a.authorize('i-uid', spy)
      assert.equal(1, spy.callCount)
      # assert.deepEqual({name: 'name lname',email: 'm@openid.inbox.lv'}, spy.getCall(0).args[0])
      assert.deepEqual({name: 'name lname', language: 'lg'}, spy.getCall(0).args[0])

    it 'request', ->
      sinon.spy(a, '_get_data')
      a.authorize 'i-uid', ->
      assert.equal(1, a._get_data.callCount)
      assert.equal(false, a._get_data.getCall(0).args[0])
      assert.deepEqual({
        action: 'userdata'
        app: 'api key'
        apiKey: 'i-uid'
        # data: 'fname,lname,mail'
        data: 'fname,lname'
      }, a._get_data.getCall(0).args[1])


  describe 'payment', ->
    spy = null
    beforeEach ->
      spy = sinon.spy()
      a._get_data = (p, data, callback)->
        callback({
          code: '200 OK',
          id: '52dc100a1d',
          link: 'https://payment.inbox.lv/'
        })

    it 'ok', ->
      a.transaction_create(33, 'en', spy)
      assert.equal(1, spy.callCount)
      assert.deepEqual({link: 'https://payment.inbox.lv/', id: '52dc100a1d', language: 'en'}, spy.getCall(0).args[0])

    it 'request', ->
      sinon.spy(a, '_get_data')
      a.transaction_create '33', 'en', ->
      assert.equal(1, a._get_data.callCount)
      assert.equal(true, a._get_data.getCall(0).args[0])
      assert.deepEqual({
        action: 'transactions/create',
        dev: 'dev id',
        apiKey: 'app id',
        prices: 'hbl-33, sebl-33, paypal-33, ccard-33, sms-33',
        language: 'en',
        skin: 'popup',
        callbackURI: 'sr.lv/ibox-url'
        cancelURI: 'sr.lv/ibox-url-completed-en.html'
        returnURI: 'sr.lv/ibox-url-completed-en.html'
      }, a._get_data.getCall(0).args[1])

    it 'max price (no sms)', ->
      sinon.spy(a, '_get_data')
      a.transaction_create 712, 'en', ->
      assert.equal 'hbl-712, sebl-712, paypal-712, ccard-712', a._get_data.getCall(0).args[1].prices

    it 'language ru', ->
      sinon.spy(a, '_get_data')
      a.transaction_create '33', 'ru', ->
      assert.equal('ru', a._get_data.getCall(0).args[1].language)

    it 'language other', ->
      sinon.spy(a, '_get_data')
      a.transaction_create '33', 'lg', ->
      assert.equal('lv', a._get_data.getCall(0).args[1].language)


  describe 'transaction check', ->
    spy = null
    spy_error = null
    callback_data = null
    beforeEach ->
      callback_data =
        code: '200 OK',
        status: 'COMPLETED'
      spy = sinon.spy()
      spy_error = sinon.spy()
      a._get_data = (p, data, callback)-> callback(callback_data)

    it 'ok', ->
      a.transaction_check('5', spy, spy_error)
      assert.equal(1, spy.callCount)
      assert.equal(0, spy_error.callCount)

    it 'in progress', ->
      callback_data.status = 'IN_PROGRESS'
      a.transaction_check('5', spy, spy_error)
      assert.equal(0, spy.callCount)
      assert.equal(1, spy_error.callCount)

    it 'request', ->
      sinon.spy(a, '_get_data')
      a.transaction_check('52dc100a1d', spy)
      assert.equal(1, a._get_data.callCount)
      assert.equal(true, a._get_data.getCall(0).args[0])
      assert.deepEqual({
        action: 'transactions/check',
        dev: 'dev id',
        id: '52dc100a1d'
      }, a._get_data.getCall(0).args[1])
