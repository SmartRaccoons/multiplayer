assert = require('assert')
sinon = require('sinon')
crypto = require('crypto-js')
proxyquire = require('proxyquire')


fbgraph = {}
ApiOdnoklassniki = proxyquire('../odnoklassniki', {
}).ApiOdnoklassniki


describe 'ApiOdnoklassniki', ->
  spy = null
  o = null

  beforeEach ->
    spy = sinon.spy()
    o = new ApiOdnoklassniki({odnoklassniki: {app_key_secret: 'aks'}})


  describe 'buy_params', ->
    beforeEach ->
      o._validate_url = sinon.fake.returns true

    it 'ok', ->
      o.buy_params {amount: '5000', extra_attributes: '{"transaction_id":"5"}' }, spy
      assert.equal 1, o._validate_url.callCount
      assert.deepEqual {amount: '5000', extra_attributes: '{"transaction_id":"5"}' }, o._validate_url.getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.deepEqual {transaction_id: '5', price: 5000}, spy.getCall(0).args[0]

    it 'json error', ->
      o.buy_params {amount: '5000', extra_attributes: '{"transaction_id":"5"}}' }, spy
      assert.equal 1, spy.callCount
      assert.equal null, spy.getCall(0).args[0]
      assert.equal 'json error', spy.getCall(0).args[1]

    it 'not valid url', ->
      o._validate_url = -> false
      o.buy_params {amount: '5000', extra_attributes: '{"transaction_id":"5"}' }, spy
      assert.equal 1, spy.callCount
      assert.equal null, spy.getCall(0).args[0]
      assert.equal 'signature', spy.getCall(0).args[1]
      assert.equal 104, spy.getCall(0).args[2]
