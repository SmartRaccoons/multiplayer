assert = require('assert')
sinon = require('sinon')
crypto = require('crypto-js')
proxyquire = require('proxyquire')


fbgraph = {}
ApiFacebook = proxyquire('../facebook', {
  'fbgraph': fbgraph
}).ApiFacebook


describe 'ApiFacebook', ->
  spy = null
  o = null
  key = 'bd23a0c148ae8dafc826bbb84e9aaece'
  hash = (request, key_other, prefix = '')->
    request_base64 = crypto.enc.Base64.stringify(crypto.enc.Utf8.parse(request))
    prefix + [
      crypto.enc.Base64.stringify( crypto.HmacSHA256(request_base64, key_other or key) ).replace(/\+/g, '-').replace(/\//g, '_')
      request_base64
    ].join('.')

  beforeEach ->
    spy = sinon.spy()
    o = new ApiFacebook({key})


  describe '_authorize', ->
    beforeEach ->
      o._instant_validate = sinon.fake.returns true
      o._instant_get_encoded_data = sinon.fake.returns {facebook_uid: 'more'}
      o._authorize_facebook = sinon.spy()

    it 'instant', ->
      o.authorize 'code', spy
      assert.equal 1, o._instant_validate.callCount
      assert.equal 'code', o._instant_validate.getCall(0).args[0]
      assert.equal 1, o._instant_get_encoded_data.callCount
      assert.equal 'code', o._instant_get_encoded_data.getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.deepEqual {facebook_uid: 'more'}, spy.getCall(0).args[0]
      assert.equal 0, o._authorize_facebook.callCount

    it 'instant invalid', ->
      o._instant_validate = sinon.fake.returns false
      o.authorize 'code', spy
      assert.equal 0, o._instant_get_encoded_data.callCount
      assert.equal 1, o._authorize_facebook.callCount
      assert.equal 'code', o._authorize_facebook.getCall(0).args[0]
      o._authorize_facebook.getCall(0).args[1]('d')
      assert.equal 1, spy.callCount
      assert.equal 'd', spy.getCall(0).args[0]

    it '_signed_request_validate', ->
      request = '{"original":"āuch"}'
      assert.equal true, o._signed_request_validate hash(request)
      assert.equal false, o._signed_request_validate( hash(request, 'otherkey') )
      assert.equal true, o._signed_request_validate hash(request, 'otherkey'), 'otherkey'
      assert.equal false, o._signed_request_validate( hash(request).substr(4) )
      assert.equal false, o._signed_request_validate( 'agyas.sysuf' )
      assert.equal false, o._signed_request_validate( '' )

    it '_signed_request_parse', ->
      assert.deepEqual {player_id: 5, request_payload: 'r_payl'}, o._signed_request_parse hash(JSON.stringify({player_id: 5, request_payload: "r_payl"}))
      assert.equal null, o._signed_request_parse hash('err')


  describe '_authorize_facebook', ->
    beforeEach ->
      fbgraph.setAccessToken = sinon.spy()
      fbgraph.get = sinon.spy()

    it 'success', ->
      o._authorize_facebook('code', spy)
      assert.equal(1, fbgraph.setAccessToken.callCount)
      assert.equal('code', fbgraph.setAccessToken.getCall(0).args[0])
      assert.equal(1, fbgraph.get.callCount)
      assert.equal('/me?fields=token_for_business,locale,name,picture.width(100)', fbgraph.get.getCall(0).args[0])
      fbgraph.get.getCall(0).args[1](null, {id: '56', token_for_business: 'tf', name: 'n', locale: 'en_GB', picture: {data: {url: 'im'}}})
      assert.equal(1, spy.callCount)
      assert.deepEqual({facebook_uid: '56', facebook_token_for_business: 'tf', name: 'n', img: 'im', language: 'en_GB'}, spy.getCall(0).args[0])

    it 'success (no user id)', ->
      o._authorize_facebook('code', spy)
      fbgraph.get.getCall(0).args[1](null, {id: undefined})
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])

    it 'success no img', ->
      o._authorize_facebook('code', spy)
      fbgraph.get.getCall(0).args[1](null, {id: '56', name: 'n', picture: null})
      assert.equal(null, spy.getCall(0).args[0].img)

    it 'error', ->
      o._authorize_facebook('code', spy)
      fbgraph.get.getCall(0).args[1]('err', null)
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])


  describe '_instant_validate', ->
    beforeEach ->
      o._signed_request_validate = sinon.fake.returns true

    it 'default', ->
      assert.equal true, o._instant_validate 'fbinstant:tr'
      assert.equal 1, o._signed_request_validate.callCount
      assert.equal 'tr', o._signed_request_validate.getCall(0).args[0]

    it 'validate false', ->
      o._signed_request_validate = -> false
      assert.equal false, o._instant_validate 'fbinstant:tr'

    it 'not string', ->
      assert.equal false, o._instant_validate {}


  describe '_instant_get_encoded_data', ->
    data = null
    beforeEach ->
      data = {player_id: 5, request_payload: "en_US;Nāme;UltraPhoto"}
      o._signed_request_parse = sinon.fake -> data

    it 'default', ->
      assert.deepEqual {facebook_uid: 5, language: 'en_US', name: 'Nāme', img: 'UltraPhoto'}, o._instant_get_encoded_data('fbinstant:da')
      assert.equal 1, o._signed_request_parse.callCount
      assert.equal 'da', o._signed_request_parse.getCall(0).args[0]

    it 'no image', ->
      data.request_payload = "en_US;Nāme"
      assert.equal null, o._instant_get_encoded_data('fbinstant:da').img

    it 'return null', ->
      o._signed_request_parse = -> null
      assert.equal null, o._instant_get_encoded_data({})

    it 'not string', ->
      assert.equal null, o._instant_get_encoded_data({})
