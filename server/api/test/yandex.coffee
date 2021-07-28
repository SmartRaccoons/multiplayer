assert = require('assert')
sinon = require('sinon')
crypto = require('crypto')
proxyquire = require('proxyquire')


fbgraph = {}
ApiYandex = proxyquire('../yandex', {
}).ApiYandex


describe 'ApiYandex', ->
  spy = null
  o = null
  json = null
  json_data = null
  base64 = (data)-> Buffer.from(data).toString('base64')
  data_get = =>
    hmac = crypto.createHmac('sha256', 'aks')
    hmac.update(json)
    return hmac.digest('base64') + '.' + base64(json)

  beforeEach ->
    spy = sinon.spy()
    json_data =
      algorithm: 'HMAC-SHA256',
      issuedAt: 1627382109,
      requestPayload: '',
      data:
        id: "id2",
        uniqueID: 'uniquserid',
        lang: 'en',
        publicName: 'Volterios',
        avatarIdHash: '0',
        scopePermissions: { avatar: 'allow', public_name: 'allow' }
    json = JSON.stringify json_data
    o = new ApiYandex({yandex: {app_key: 'aks'}})

  it 'check sign', ->
    json = JSON.stringify {da: 'ta'}
    assert.deepEqual {da: 'ta'}, o._sign_check( data_get() )
    assert.equal null, o._sign_check( '6' + data_get())
    assert.equal null, o._sign_check( data_get().split('.')[0] )
    assert.equal null, o._sign_check( 'randomstring' )
    json = 'fg'
    assert.equal null, o._sign_check( data_get() )


  describe 'authorize', ->
    beforeEach ->
      o._sign_check = sinon.fake.returns json_data

    it 'default', ->
      data = data_get()
      o.authorize data, spy
      assert.equal 1, o._sign_check.callCount
      assert.equal data, o._sign_check.getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.deepEqual {uid: 'uniquserid', language: 'en', name: 'Volterios', img: 'https://games-sdk.yandex.ru/api/sdk/v1/player/avatar/0/islands-retina-small'}, spy.getCall(0).args[0]

    it 'sign invalid', ->
      o._sign_check = -> null
      o.authorize data_get(), spy
      assert.equal null, spy.getCall(0).args[0]

    it 'uid isnt exist', ->
      json_data.data.uniqueID = ''
      o.authorize data_get(), spy
      assert.equal null, spy.getCall(0).args[0]
