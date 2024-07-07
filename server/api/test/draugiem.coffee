assert = require('assert')
sinon = require('sinon')


class ApiDraugiem extends require('../draugiem').ApiDraugiem
  app_id: 'bena'
  _getUrl: (url, callback)->
    #json parse error
    if 'https://api.draugiem.lv/json/?&code=json-parse&app=bena&action=authorize' is url
      callback('{"apikey":"2af","uid":"91638","langua')
    #json-error
    if 'https://api.draugiem.lv/json/?&code=json-erorr&app=bena&action=authorize' is url
      callback('{"error":{"description":"Access denied","code":150}}')
    #ok
    if 'https://api.draugiem.lv/json/?&code=dr-auth-code&app=bena&action=authorize' is url
      callback('{"apikey":"2af","uid":"91638","language":"lv","users":{"91638":{"uid":91638,"name":"Nikolajs","surname":"Mediks","nick":"","place":"","img":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/sm_91638.jpg","imgi":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/i_91638.jpg","imgm":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/nm_91638.jpg","imgl":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/l_91638.jpg","sex":"M","birthday":"1983-11-09","age":28,"adult":1,"type":"User_Default","created":"08.11.2004 14:30:52","deleted":false}}}')
    if 'https://api.draugiem.lv/json/?&code=dr-auth-code2&app=bena&action=authorize' is url
      callback('{"apikey":"2af","uid":"91638","language":"lv","users":{"91638":{"uid":91638,"name":"Nikolajs 🖤N2","surname":"Mediks🖤 M2","nick":"","place":"","img":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/sm_91638.jpg","imgi":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/i_91638.jpg","imgm":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/nm_91638.jpg","imgl":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/l_91638.jpg","sex":"M","birthday":"1983-11-09","age":28,"adult":1,"type":"User_Default","created":"08.11.2004 14:30:52","deleted":false}}}')
    #next request after authorize
    if 'https://api.draugiem.lv/json/?&app=bena&action=apikey&apikey=2af' is url
      callback('{"check": "true"}')
    #payment
    if 'https://api.draugiem.lv/json/?&service=2&price=15&app=bena&action=transactions/create&apikey=k' is url
      callback('{"transaction": {"id":1935,"link":"http://www.draugiem.lv/services/iframe.php?id=1935"}}')
    if 'https://api.draugiem.lv/json/?&service=2&price=15&app=bena&action=transactions/create&apikey=error' is url
      callback('{"transaction": {"id":1935,"link":"http://www.draugiem.lv/services/')

describe 'draugiem api', ->
  describe 'authorize', ->
    it 'json error', ->
      a = new ApiDraugiem()
      spy = sinon.spy()
      a.authorize('json-parse', (=>), spy)
      assert.equal(1, spy.callCount)

    it 'error callback', (done)->
      a = new ApiDraugiem()
      a.authorize('json-erorr', (=>), (res)=>
        assert.equal('Access denied', res['error']['description'])
        done()
      )

    it 'success', (done)->
      a = new ApiDraugiem()
      assert.equal(null, a.user)
      a.authorize 'dr-auth-code', (user)=>
        assert.equal('Nikolajs', user.name)
        assert.equal(91638, user.uid)
        assert.equal('2af', a.app_key)
        assert.equal(null, user.inviter)
        a.apiGet 'apikey', {}, (res)=>
          assert.equal 'true', res['check']
          done()

    it 'success utf8 name', (done)->
      a = new ApiDraugiem()
      a.authorize 'dr-auth-code2', (user)=>
        assert.equal('Nikolajs N2', user.name)
        assert.equal('Mediks M2', user.surname)
        done()

    it 'success with inviter', ->
      a = new ApiDraugiem()
      a._getUrl = sinon.spy()
      user = sinon.spy()
      a.authorize('dr-auth-inviter', user)
      assert.equal('https://api.draugiem.lv/json/?&code=dr-auth-inviter&app=bena&action=authorize', a._getUrl.getCall(0).args[0])
      a._getUrl.getCall(0).args[1]('{"apikey":"2af","uid":"91638","language":"lv","inviter":"10","users":{"91638":{"uid":91638,"name":"Nikolajs","surname":"Mediks","nick":"","place":"","img":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/sm_91638.jpg","imgi":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/i_91638.jpg","imgm":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/nm_91638.jpg","imgl":"http:\/\/i8.ifrype.com\/profile\/091\/638\/v1\/l_91638.jpg","sex":"M","birthday":"1983-11-09","age":28,"adult":1,"type":"User_Default","created":"08.11.2004 14:30:52","deleted":false}}}')
      assert.equal(10, user.getCall(0).args[0].inviter)

  describe 'payments', ->
    it 'transaction creating', ->
      a = new ApiDraugiem()
      spy = sinon.spy()
      a.app_key = 'k'
      a.transactionCreate(2, 15, spy)
      assert.equal(1935, spy.getCall(0).args[0].id)
      assert.equal('http://www.draugiem.lv/services/iframe.php?id=1935', spy.getCall(0).args[0].link)

    it 'app_key error', ->
      a = new ApiDraugiem()
      spy = sinon.spy()
      spyerror = sinon.spy()
      a.transactionCreate(2, 15, spy, spyerror)
      assert.equal(0, spy.callCount)
      assert.equal(1, spyerror.callCount)

    it 'transaction error', ->
      a = new ApiDraugiem()
      spy = sinon.spy()
      spyerror = sinon.spy()
      a.app_key = 'error'
      a.transactionCreate(2, 15, spy, spyerror)
      assert.equal(0, spy.callCount)
      assert.equal(1, spyerror.callCount)

  describe 'fetch friends', ->
    it 'success', ->
      a = new ApiDraugiem()
      geturl = sinon.spy()
      a._getUrl = geturl
      spy = sinon.spy()
      a.app_key = 'friends'
      a.friends(spy)
      assert.equal('https://api.draugiem.lv/json/?&show=ids&page=1&limit=200&app=bena&action=app_friends&apikey=friends', geturl.getCall(0).args[0])
      assert.equal(0, spy.callCount)
      geturl.getCall(0).args[1]('{"total":200,"userids":{"7552":7552,"24108":24108}}')
      assert.equal(1, spy.callCount)
      assert.deepEqual([7552, 24108], spy.getCall(0).args[0])

    it '2 pages', ->
      a = new ApiDraugiem()
      geturl = sinon.spy()
      a._getUrl = geturl
      spy = sinon.spy()
      a.app_key = 'friends'
      a.friends(spy)
      assert.equal('https://api.draugiem.lv/json/?&show=ids&page=1&limit=200&app=bena&action=app_friends&apikey=friends', geturl.getCall(0).args[0])
      geturl.getCall(0).args[1]('{"total":201,"userids":{"7552":7552,"24108":24108}}')
      assert.equal(0, spy.callCount)
      assert.equal('https://api.draugiem.lv/json/?&show=ids&page=2&limit=200&app=bena&action=app_friends&apikey=friends', geturl.getCall(1).args[0])
      geturl.getCall(1).args[1]('{"total":201,"userids":{"7552":7556,"24108":24118}}')
      assert.deepEqual([7552, 24108, 7556, 24118], spy.getCall(0).args[0])
      assert.equal(2, geturl.callCount)

    it 'error', ->
      a = new ApiDraugiem()
      geturl = sinon.spy()
      a._getUrl = geturl
      spy = sinon.spy()
      spy_error = sinon.spy()
      a.app_key = 'friends'
      a.friends(spy, spy_error)
      geturl.getCall(0).args[1]('{"total":201,"userids":{"7552":7552,"24108":24108}}')
      geturl.getCall(1).args[1]('{"total":201,"userids":{"7552"')
      assert.equal(0, spy.callCount)
      assert.equal(1, spy_error.callCount)
