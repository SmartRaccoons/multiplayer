events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class Facebook
class User

helpers_email = {}

config = {}
urls = proxyquire('../urls', {
  '../../config':
    config_callback: (c)-> c
    module_get: (plugin)->
      if plugin is 'server.helpers.email'
        return helpers_email
      { facebook: Facebook, User }
    config_get: (p)-> config[p]
})


describe 'Urls', ->
  spy = null
  res = null
  app = null
  beforeEach ->
    config =
      server: 'http://ser.vo'
    spy = sinon.spy()
    res =
      send: sinon.spy()
      json: sinon.spy()
      sendStatus: sinon.spy()
    app =
      all: sinon.spy()
      get: sinon.spy()
      post: sinon.spy()

  afterEach ->


  describe 'delete facebook request', ->
    body = null
    deletion_request = null
    beforeEach ->
      Facebook::deletion_request = deletion_request = sinon.spy()
      config.facebook = { id: 'appid', deletion_callback: 'fb_del_callback', deletion_url: '/fb_del' }
      body =
        signed_request: 'signed_r'
      urls.authorize(app)
      helpers_email.send_admin = sinon.spy()

    it 'default', ->
      assert.equal 'fb_del_callback', app.post.getCall(0).args[0]
      app.post.getCall(0).args[1] { method: 'POST', body: body }, res
      assert.equal 1, deletion_request.callCount
      assert.equal 'signed_r', deletion_request.getCall(0).args[0]
      deletion_request.getCall(0).args[1] {code: 'cd'}
      assert.equal 1, res.json.callCount
      assert.deepEqual {confirmation_code: 'cd', url: 'http://ser.vo/fb_del/cd'}, res.json.getCall(0).args[0]
      assert.equal 1, helpers_email.send_admin.callCount
      assert.deepEqual {subject: 'Deletion request', text: ''}, helpers_email.send_admin.getCall(0).args[0]

    it 'no result', ->
      app.post.getCall(0).args[1] { method: 'POST', body: body }, res
      deletion_request.getCall(0).args[1] null
      assert.equal 0, res.json.callCount
      assert.equal 1, res.sendStatus.callCount
      assert.equal 404, res.sendStatus.getCall(0).args[0]


  describe 'delete facebook status', ->
    body = null
    deletion_status = null
    beforeEach ->
      Facebook::deletion_status = deletion_status = sinon.spy()
      config.facebook = { id: 'appid', deletion_callback: 'fb_del_callback', deletion_url: '/fb_del' }
      urls.authorize(app)

    it 'default', ->
      assert.equal '/fb_del/:code', app.get.getCall(0).args[0]
      app.get.getCall(0).args[1] { params: {code: 'cd2'} }, res
      assert.equal 1, deletion_status.callCount
      assert.equal 'cd2', deletion_status.getCall(0).args[0]
      deletion_status.getCall(0).args[1]({status: 'Init'})
      assert.equal 1, res.send.callCount
      assert.equal true, res.send.getCall(0).args[0].indexOf('Init') >= 0

    it 'default', ->
      app.get.getCall(0).args[1] { params: {code: 'cd2'} }, res
      deletion_status.getCall(0).args[1]()
      assert.equal 1, res.send.callCount
      assert.equal false, res.send.getCall(0).args[0].indexOf('Init') >= 0
      assert.equal true, res.send.getCall(0).args[0].indexOf('Something is wrong') >= 0


  describe 'payments', ->
    req = null
    _buy_callback = null
    beforeEach ->
      User::_buy_callback = _buy_callback = sinon.spy()

    describe 'facebook', ->
      req_subscription = null
      req_payment = null
      buy_complete = null
      beforeEach ->
        req_subscription = {"object":"payment_subscriptions","entry":[{"id":"301663523297285","time":1585236197,"changed_fields":["status","next_period_amount","next_period_currency","next_bill_time","next_period_product","product"]}]}
        req_payment = {"object":"payments","entry":[{"id":"1234719854"}]}
        req =
          method: 'POST'
          body: req_payment
        config.facebook = { id: 'appid', transaction: 'trurl' }
        Facebook::buy_complete = buy_complete = sinon.spy()

        urls.payments(app)

      it 'test get', ->
        app.all.getCall(0).args[1] { method: 'GET', query: { 'hub.challenge': 'hch' } }, res
        assert.equal 1, res.send.callCount
        assert.equal 'hch', res.send.getCall(0).args[0]

      it 'payment', ->
        req.body = req_payment
        assert.equal 1, app.all.callCount
        assert.equal 'trurl', app.all.getCall(0).args[0]
        app.all.getCall(0).args[1] req, res
        assert.equal 1, buy_complete.callCount
        assert.deepEqual {id: '1234719854'}, buy_complete.getCall(0).args[0]
        buy_complete.getCall(0).args[1]({p: 'ram'})
        assert.equal 1, _buy_callback.callCount
        assert.deepEqual {platform: 'facebook', p: 'ram'}, _buy_callback.getCall(0).args[0]
        buy_complete.getCall(0).args[2]()
        assert.equal 1, res.send.callCount
        assert.equal 'OK', res.send.getCall(0).args[0]

      it 'payment (entry length not 1)', ->
        req_payment.entry.push {id: '3444'}
        req.body = req_payment
        app.all.getCall(0).args[1] req, res
        assert.equal 0, buy_complete.callCount
        assert.equal 1, res.sendStatus.callCount
        assert.equal 404, res.sendStatus.getCall(0).args[0]

      it 'payment (buy_complete error)', ->
        req.body = req_payment
        app.all.getCall(0).args[1] req, res
        buy_complete.getCall(0).args[2]('err')
        assert.equal 0, res.send.callCount
        assert.equal 1, res.sendStatus.callCount
        assert.equal 404, res.sendStatus.getCall(0).args[0]

      it 'payment (buy_complete error - incompleted)', ->
        req.body = req_payment
        app.all.getCall(0).args[1] req, res
        buy_complete.getCall(0).args[2]('incompleted')
        assert.equal 1, res.send.callCount
        assert.equal 0, res.sendStatus.callCount

      it 'payment (body payments diff)', ->
        req_payment.object = 'not-payments'
        req.body = req_payment
        app.all.getCall(0).args[1] req, res
        assert.equal 0, buy_complete.callCount
        assert.equal 1, res.sendStatus.callCount
        assert.equal 404, res.sendStatus.getCall(0).args[0]

      it 'payment (body empty)', ->
        req.body = null
        app.all.getCall(0).args[1] req, res
        assert.equal 0, buy_complete.callCount
        assert.equal 1, res.sendStatus.callCount
        assert.equal 404, res.sendStatus.getCall(0).args[0]

      it 'subscription', ->
        req.body = req_subscription
        app.all.getCall(0).args[1] req, res
        assert.deepEqual {id: '301663523297285', subscription: true}, buy_complete.getCall(0).args[0]
