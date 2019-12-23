events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class Facebook
class User

config = {}
urls = proxyquire('../urls', {
  '../../config':
    config_callback: (c)-> c
    module_get: -> { facebook: Facebook, User }
    config_get: (p)-> config[p]
})


describe 'Urls', ->
  spy = null
  beforeEach ->
    spy = sinon.spy()

  afterEach ->


  describe 'payments', ->
    app = null
    req = null
    res = null
    _buy_callback = null
    beforeEach ->
      res =
        send: sinon.spy()
        sendStatus: sinon.spy()
      app =
        all: sinon.spy()
        get: sinon.spy()
        post: sinon.spy()
      User::_buy_callback = _buy_callback = sinon.spy()


    describe 'facebook', ->
      req_subscription = null
      req_payment = null
      res = null
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
