events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


TestFacebook = {}
TestDraugiem_authrorize = null

Google_Authorize =
  authorize: null
Inbox_Authorize =
  constructor: ->
  authorize: null
  transaction_create: null

config = {}
config_callbacks = []
Authorize = proxyquire '../authorize',
  '../api/draugiem':
    ApiDraugiem: class ApiDraugiem
      authorize: ->
        TestDraugiem_authrorize.apply(@, arguments)
        @app_key = 'auth'
  'fbgraph': TestFacebook
  '../api/google':
    ApiGoogle: class ApiGoogle
      authorize: -> Google_Authorize.authorize.apply(@, arguments)
  '../api/inbox':
    ApiInbox: class ApiInbox
      constructor: -> Inbox_Authorize.constructor.apply(@, arguments)
      authorize: -> Inbox_Authorize.authorize.apply(@, arguments)
      transaction_create: -> Inbox_Authorize.transaction_create.apply(@, arguments)
  '../../config':
    config_get: (param)-> config[param]
    config_callback: (c)-> config_callbacks.push c

LoginDraugiem = Authorize.draugiem
LoginFacebook = Authorize.facebook
LoginGoogle = Authorize.google
LoginInbox = Authorize.inbox
Login = Authorize.Login


describe 'Athorize', ->
  spy = null
  spy2 = null
  clock = null
  db = {}
  beforeEach ->
    clock = sinon.useFakeTimers()
    config =
      buy:
        1: 3
      draugiem:
        buy_transaction:
          1: 444
      inbox:
        buy_price:
          1: 70
      google:
        id: 'gid'
      facebook:
        id: 'fid'
        key: 'fkey'
      db: db
    Authorize.config_attr
      language:
        validate: ->
    config_callbacks[0]()
    db.select_one = sinon.spy()
    db.update = sinon.spy()
    db.insert = sinon.spy()
    db.select = sinon.spy()
    spy = sinon.spy()
    spy2 = sinon.spy()
    TestDraugiem_authrorize = sinon.spy()
    TestDraugiem_transactionCreate = sinon.spy()
    TestFacebook.setAccessToken = sinon.spy()
    TestFacebook.get = sinon.spy()

  afterEach ->
    clock.restore()

  describe 'Login', ->
    login = null
    beforeEach ->
      login = new Login()

    it '_user_get', ->
      login._user_get({id: 5}, spy)
      assert.equal(1, db.select_one.callCount)
      assert(db.select_one.getCall(0).args[0].select.indexOf('id') >= 0)
      assert.equal('auth_user', db.select_one.getCall(0).args[0].table)
      assert.deepEqual({id: 5}, db.select_one.getCall(0).args[0].where)
      db.select_one.getCall(0).args[1]({id: 5})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5, new: false}, spy.getCall(0).args[0])

    it '_user_get update', ->
      login._user_get({id: 5}, spy)
      db.select_one.getCall(0).args[1]({id: 5})
      assert.equal(1, db.update.callCount)
      assert.equal('auth_user', db.update.getCall(0).args[0].table)
      assert.deepEqual(['last_login'], Object.keys(db.update.getCall(0).args[0].data))
      assert.deepEqual({id: 5}, db.update.getCall(0).args[0].where)

    it '_user_get update additional', ->
      login._user_get({id: 5}, {name: 's a'}, spy)
      db.select_one.getCall(0).args[1]({id: 5, name: 'other'})
      assert.deepEqual(['last_login', 'name'], Object.keys(db.update.getCall(0).args[0].data))
      assert.equal('s a', db.update.getCall(0).args[0].data.name)
      assert.equal('s a', spy.getCall(0).args[0].name)

    it '_user_get not found', ->
      login._user_get({id: 5}, spy)
      db.select_one.getCall(0).args[1](null)
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])
      assert.equal(0, db.update.callCount)

    it '_user_create', ->
      login._user_create({draugiem_uid: 5}, spy)
      assert.equal(1, db.insert.callCount)
      assert.equal('auth_user', db.insert.getCall(0).args[0].table)
      assert.equal(5, db.insert.getCall(0).args[0].data.draugiem_uid)
      assert.equal('', db.insert.getCall(0).args[0].data.img)
      db.insert.getCall(0).args[1](2)
      assert.equal(1, spy.callCount)
      assert.equal(2, spy.getCall(0).args[0].id)
      assert.equal(5, spy.getCall(0).args[0].draugiem_uid)
      assert.equal(true, spy.getCall(0).args[0].new)

    it '_user_create (addtitional _attr)', ->
      Authorize.config_attr
        rating: {default: 1600, db: true}
      login._user_create({draugiem_uid: 5}, spy)
      assert.equal(1600, db.insert.getCall(0).args[0].data.rating)

    it '_user_create (default language)', ->
      Authorize._attr.language.validate = stub = sinon.stub()
      stub.returns('lv')
      login._user_create({draugiem_uid: 5, language: 'lv_GB'}, spy)
      assert.equal(1, stub.callCount)
      assert.equal('lv_GB', stub.getCall(0).args[0])
      assert.equal('lv', db.insert.getCall(0).args[0].data.language)

    it '_user_create_or_update (update)', ->
      login._user_create = sinon.spy()
      login._user_get = sinon.spy()
      login._user_create_or_update({draugiem_uid: 5}, {name: 'h l', language: 'lv'}, spy)
      assert.equal(1, login._user_get.callCount)
      assert.deepEqual({draugiem_uid: 5}, login._user_get.getCall(0).args[0])
      assert.deepEqual({name: 'h l'}, login._user_get.getCall(0).args[1])
      login._user_get.getCall(0).args[2]({id: 4})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 4}, spy.getCall(0).args[0])
      assert.equal(0, login._user_create.callCount)

    it '_user_create_or_update (new)', ->
      login._user_create = sinon.spy()
      login._user_get = sinon.spy()
      login._user_create_or_update({draugiem_uid: 5}, {name: 'h l', language: 'lv'}, spy)
      login._user_get.getCall(0).args[2](null)
      assert.equal(1, login._user_create.callCount)
      assert.deepEqual({draugiem_uid: 5, name: 'h l', language: 'lv'}, login._user_create.getCall(0).args[0])
      login._user_create.getCall(0).args[1]({id: 5})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5}, spy.getCall(0).args[0])

    it '_user_update', ->
      login._user_update({name: 's', new: false, id: 3})
      assert.equal(1, db.update.callCount)
      assert.equal('auth_user', db.update.getCall(0).args[0].table)
      assert.deepEqual({id: 3}, db.update.getCall(0).args[0].where)
      assert.deepEqual({name: 's'}, db.update.getCall(0).args[0].data)

    it '_user_update (no params)', ->
      login._user_update({new: false, id: 3})
      assert.equal(0, db.update.callCount)

    it 'db check (null)', ->
      login._table_session = 's_table'
      login._user_get = sinon.spy()
      login._user_session_check('cd', spy)
      assert.equal(1, db.select_one.callCount)
      date = new Date()
      date.setDate(date.getDate() - 30)
      assert.deepEqual({
        table: 's_table'
        where: {code: 'cd', last_updated: {sign: ['>', date]}}
      }, db.select_one.getCall(0).args[0])
      db.select_one.getCall(0).args[1](null)
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])
      assert.equal(0, login._user_get.callCount)

    it 'db check', ->
      login._user_get = sinon.spy()
      login._user_session_check('cd', spy)
      db.select_one.getCall(0).args[1]({id: 5, user_id: 6})
      assert.equal(1, login._user_get.callCount)
      assert.deepEqual({id: 6}, login._user_get.getCall(0).args[0])

    it 'db check callback', ->
      login._user_get = sinon.spy()
      login._user_session_check('cd', spy)
      db.select_one.getCall(0).args[1]({id: 5, api_key: 'ky'})
      login._user_get.getCall(0).args[1]({id: 5, new: false})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5, new: false}, spy.getCall(0).args[0])
      assert.deepEqual('ky', spy.getCall(0).args[1].api_key)

    it 'db check update', ->
      login._table_session = 's_table'
      login._user_get = sinon.spy()
      login._user_session_check('cd', spy)
      db.select_one.getCall(0).args[1]({id: 5, api_key: 'ky'})
      assert.equal(1, db.update.callCount)
      assert.equal('s_table', db.update.getCall(0).args[0].table)
      assert.deepEqual({id: 5}, db.update.getCall(0).args[0].where)

    it '_user_session_save', ->
      login._table_session = 's_table'
      login._user_session_save({user_id: 'ben'})
      assert.equal(1, db.insert.callCount)
      assert.equal('s_table', db.insert.getCall(0).args[0].table)
      assert.deepEqual({user_id: 'ben', last_updated: new Date()}, db.insert.getCall(0).args[0].data)

    it '_transaction_create', ->
      login._table_transaction = 's_trans'
      login._transaction_create({tr: 't', service: 1}, spy)
      assert.equal(1, db.insert.callCount)
      assert.equal('s_trans', db.insert.getCall(0).args[0].table)
      assert.deepEqual({tr: 't', service: 1, created: new Date()}, db.insert.getCall(0).args[0].data)
      db.insert.getCall(0).args[1](10)
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 10}, spy.getCall(0).args[0])

    it '_transaction_create (check service)', ->
      login._transaction_create({service: 5}, spy)
      assert.equal(0, db.insert.callCount)

    it '_transaction_get', ->
      login._table_transaction = 's_trans'
      login._transaction_get({id: 'pr'}, spy, spy2)
      assert.equal(1, db.select_one.callCount)
      assert.equal('s_trans', db.select_one.getCall(0).args[0].table)
      assert.deepEqual({id: 'pr', fulfill: '0'}, db.select_one.getCall(0).args[0].where)
      db.select_one.getCall(0).args[1]({id: 'z', user_id: 2, service: '3'})
      assert.equal(1, spy.callCount)
      assert.equal(2, spy.getCall(0).args[0].user_id)
      assert.equal('3', spy.getCall(0).args[0].service)
      assert.equal('z', spy.getCall(0).args[0].transaction_id)
      spy.getCall(0).args[0].complete()
      assert.equal(1, db.update.callCount)
      assert.equal('s_trans', db.update.getCall(0).args[0].table)
      assert.deepEqual({id: 'z'}, db.update.getCall(0).args[0].where)
      assert.deepEqual({fulfill: '1', fulfilled: new Date()}, db.update.getCall(0).args[0].data)
      db.update.getCall(0).args[1]()
      assert.equal(1, spy2.callCount)
      assert.equal(null, spy2.getCall(0).args[0])

    it '_transaction_get (not found)', ->
      login._table_transaction = 's_trans'
      login._transaction_get({id: 'pr'}, spy, spy2)
      db.select_one.getCall(0).args[1]()
      assert.equal(0, spy.callCount)
      assert.equal(1, spy2.callCount)
      assert.notEqual(null, spy2.getCall(0).args[0])


  describe 'Login authorize', ->
    login = null
    beforeEach ->
      login = new Login()
      login._user_session_check = sinon.spy()
      login._user_create_or_update = sinon.spy()
      login._user_session_save = sinon.spy()
      login._api_call = sinon.spy()
      login._api_session = sinon.spy()

    it 'new', ->
      login.authorize({code: 'code'})
      assert.equal(1, login._user_session_check.callCount)
      assert.equal('code', login._user_session_check.getCall(0).args[0])
      login._user_session_check.getCall(0).args[1](null)
      assert.equal(1, login._api_call.callCount)
      assert.equal('code', login._api_call.getCall(0).args[0])
      assert.equal(0, login._api_session.callCount)

    it 'new update', ->
      login.authorize({code: 'code'}, spy)
      login._user_session_check.getCall(0).args[1](null)
      login._api_call.getCall(0).args[1]({fb: '56'}, {name: 'n', img: 'im'})
      assert.equal(1, login._user_create_or_update.callCount)
      assert.deepEqual({
        fb: '56'
      }, login._user_create_or_update.getCall(0).args[0])
      assert.deepEqual({
        name: 'n'
        img: 'im'
      }, login._user_create_or_update.getCall(0).args[1])
      login._user_create_or_update.getCall(0).args[2]({id: 555})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 555}, spy.getCall(0).args[0])

    it 'authorize new (create session)', ->
      login.authorize({code: 'code'}, spy)
      login._user_session_check.getCall(0).args[1](null)
      login._api_call.getCall(0).args[1]({fb: '56'}, {name: 'n', img: 'im'}, {api: 'key'})
      login._user_create_or_update.getCall(0).args[2]({id: 2})
      assert.equal(1, login._user_session_save.callCount)
      assert.deepEqual({user_id: 2, code: 'code', api: 'key'}, login._user_session_save.getCall(0).args[0])

    it 'error', ->
      login.authorize({code: 'code'}, spy)
      login._user_session_check.getCall(0).args[1](null)
      login._api_call.getCall(0).args[1](null)
      assert.equal(0, login._user_session_save.callCount)
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])

    it 'existing', ->
      login.authorize({code: 'code'}, spy)
      login._user_session_check.getCall(0).args[1]({id: 5, name: 'bor'}, 'ses')
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5, name: 'bor'}, spy.getCall(0).args[0])
      assert.equal(0, login._api_call.callCount)
      assert.equal(1, login._api_session.callCount)
      assert.equal('ses', login._api_session.getCall(0).args[0])


  describe 'LoginDraugiem', ->
    login = null
    spy_tr = null
    beforeEach ->
      login = new LoginDraugiem()
      login._transaction_create = sinon.spy()
      login._transaction_get = sinon.spy()
      login.api =
        transactionCreate: sinon.spy()
      spy_tr = login.api.transactionCreate

    it 'default', ->
      assert.equal('auth_user_session_draugiem', login._table_session)
      assert.equal('transaction_draugiem', login._table_transaction)

    it 'success', ->
      login._api_call('code', spy)
      assert.equal(1, TestDraugiem_authrorize.callCount)
      assert.equal('code', TestDraugiem_authrorize.getCall(0).args[0])
      TestDraugiem_authrorize.getCall(0).args[1]({uid: '56', name: 'n', surname: 'sn', img: 'im', language: 'lv'})
      assert.equal(1, spy.callCount)
      assert.deepEqual({draugiem_uid: '56'}, spy.getCall(0).args[0])
      assert.deepEqual({name: 'n sn', img: 'im', language: 'lv'}, spy.getCall(0).args[1])
      assert.deepEqual({api_key: 'auth'}, spy.getCall(0).args[2])

    it 'error', ->
      login._api_call('code', spy)
      TestDraugiem_authrorize.getCall(0).args[2]('error')
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])

    it '_api_session', ->
      login._api_session({api_key: 'key'})
      assert.equal('key', login.api.app_key)

    it 'buy', ->
      login.buy({service: 1, user_id: 333}, spy)
      assert.equal(1, spy_tr.callCount)
      assert.equal(444, spy_tr.getCall(0).args[0])
      assert.equal(null, spy_tr.getCall(0).args[1])
      spy_tr.getCall(0).args[2]({id: '5', link: 'li'})
      assert.equal(1, login._transaction_create.callCount)
      assert.deepEqual({service: 1, transaction_id: '5', user_id: 333}, login._transaction_create.getCall(0).args[0])
      login._transaction_create.getCall(0).args[1](55)
      assert.equal(1, spy.callCount)
      assert.deepEqual({link: 'li'}, spy.getCall(0).args[0])

    it 'buy (no transaction)', ->
      login.buy({service: 22})
      assert.equal(0, spy_tr.callCount)

    it 'buy_complete', ->
      login.buy_complete('22', 'a', 'b')
      assert.equal(1, login._transaction_get.callCount)
      assert.deepEqual({transaction_id: '22'}, login._transaction_get.getCall(0).args[0])
      assert.equal('a', login._transaction_get.getCall(0).args[1])
      assert.equal('b', login._transaction_get.getCall(0).args[2])


  describe 'LoginFacebook', ->
    login = null
    payment_success = null
    payment_failed = null
    beforeEach ->
      payment_success = {
        "request_id": "3",
        "user": {
          "name": "Valentino Langarosa",
          "id": "10212914925362552"
        },
        "items": [
          {
            "type": "IN_APP_PURCHASE",
            "product": "https://mancala.raccoons.lv/d/og/coins2en.html",
            "quantity": 1
          }
        ],
        "actions": [
          {
            "type": "charge",
            "status": "completed",
            "currency": "EUR",
            "amount": "2.85",
            "time_created": "2018-04-22T21:30:31+0000",
            "time_updated": "2018-04-22T21:30:31+0000",
            "tax_amount": "0.49"
          }
        ],
        "id": "1197009377095918"
      }
      payment_failed = {
        "request_id": "3",
        "user": {
          "name": "Valentino Langarosa",
          "id": "10212914925362552"
        },
        "items": [
          {
            "type": "IN_APP_PURCHASE",
            "product": "https://mancala.raccoons.lv/d/og/coins2en.html",
            "quantity": 1
          }
        ],
        "actions": [
          {
            "type": "charge",
            "status": "failed",
            "currency": "EUR",
            "amount": "2.85",
            "time_created": "2018-04-22T21:30:31+0000",
            "time_updated": "2018-04-22T21:30:31+0000",
            "tax_amount": "0.49"
          }
        ],
        "id": "1197009377095918"
      }
      login = new LoginFacebook()
      login._transaction_create = sinon.spy()
      login._transaction_get = sinon.spy()
      Google_Authorize.authorize = sinon.spy()

    it 'default', ->
      assert.equal('auth_user_session_facebook', login._table_session)
      assert.equal('transaction_facebook', login._table_transaction)

    it 'success', ->
      login._api_call('code', spy)
      assert.equal(1, TestFacebook.setAccessToken.callCount)
      assert.equal('code', TestFacebook.setAccessToken.getCall(0).args[0])
      assert.equal(1, TestFacebook.get.callCount)
      assert.equal('/me?fields=locale,name,picture.width(100)', TestFacebook.get.getCall(0).args[0])
      TestFacebook.get.getCall(0).args[1](null, {id: '56', name: 'n', locale: 'en_GB', picture: {data: {url: 'im'}}})
      assert.equal(1, spy.callCount)
      assert.deepEqual({facebook_uid: '56'}, spy.getCall(0).args[0])
      assert.deepEqual({name: 'n', img: 'im', language: 'en_GB'}, spy.getCall(0).args[1])

    it 'success no img', ->
      login._api_call('code', spy)
      TestFacebook.get.getCall(0).args[1](null, {id: '56', name: 'n', picture: null})
      assert.equal(null, spy.getCall(0).args[1].img)

    it 'error', ->
      login._api_call('code', spy)
      TestFacebook.get.getCall(0).args[1]('err', null)
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])

    it 'buy', ->
      login.buy({user_id: 5, service: 2}, spy)
      assert.equal(1, login._transaction_create.callCount)
      assert.deepEqual({service: 2, user_id: 5}, login._transaction_create.getCall(0).args[0])
      login._transaction_create.getCall(0).args[1]({id: 10})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 10}, spy.getCall(0).args[0])

    it 'buy_complete', ->
      TestFacebook.get = sinon.spy()
      login.buy_complete '33', 'a', 'b'
      assert.equal(1, TestFacebook.get.callCount)
      assert.equal('/33?fields=request_id,user,actions,items&access_token=fid|fkey', TestFacebook.get.getCall(0).args[0])
      TestFacebook.get.getCall(0).args[1](null, payment_success)
      assert.equal(1, login._transaction_get.callCount)
      assert.deepEqual({id: '3'}, login._transaction_get.getCall(0).args[0])
      assert.equal('a', login._transaction_get.getCall(0).args[1])
      assert.equal('b', login._transaction_get.getCall(0).args[2])

    it 'buy_complete (err)', ->
      TestFacebook.get = sinon.spy()
      login.buy_complete '33', 'a', spy
      TestFacebook.get.getCall(0).args[1]('err')
      assert.equal(0, login._transaction_get.callCount)
      assert.equal(1, spy.callCount)
      assert.equal('err', spy.getCall(0).args[0])

    it 'buy_complete (failure)', ->
      TestFacebook.get = sinon.spy()
      login.buy_complete '33', 'a', spy
      TestFacebook.get.getCall(0).args[1](null, payment_failed)
      assert.equal(0, login._transaction_get.callCount)
      assert.equal(1, spy.callCount)
      assert.equal('incompleted: 33', spy.getCall(0).args[0])


  describe 'LoginGoogle', ->
    login = null
    beforeEach ->
      login = new LoginGoogle()
      Google_Authorize.authorize = sinon.spy()

    it 'default', ->
      assert.equal('auth_user_session_google', login._table_session)

    it 'success', ->
      login._api_call('code', spy)
      assert.equal(1, Google_Authorize.authorize.callCount)
      assert.equal('code', Google_Authorize.authorize.getCall(0).args[0])
      Google_Authorize.authorize.getCall(0).args[1]({uid: 'as', language: 'en-GB', name: 'n', img: 'p'})
      assert.equal(1, spy.callCount)
      assert.deepEqual({google_uid: 'as'}, spy.getCall(0).args[0])
      assert.deepEqual({name: 'n', img: 'p', language: 'en-GB'}, spy.getCall(0).args[1])

    it 'error', ->
      login._api_call('code', spy)
      Google_Authorize.authorize.getCall(0).args[1](null)
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])


  describe 'LoginInbox', ->
    login = null
    beforeEach ->
      login = new LoginInbox()
      login._user_get = sinon.spy()
      login._user_create = sinon.spy()
      login._transaction_create = sinon.spy()
      login._transaction_get = sinon.spy()
      Inbox_Authorize.authorize = sinon.spy()
      Inbox_Authorize.transaction_create = sinon.spy()

    it 'default', ->
      assert.equal('transaction_inbox', login._table_transaction)

    it 'success', ->
      login.authorize({code: 'code'}, spy)
      assert.equal(1, login._user_get.callCount)
      assert.deepEqual({inbox_uid: 'code'}, login._user_get.getCall(0).args[0])
      login._user_get.getCall(0).args[1]({id: 2})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 2}, spy.getCall(0).args[0])

    it 'api call', ->
      login.authorize({code: 'code', language: 'lv'}, spy)
      login._user_get.getCall(0).args[1](null)
      assert.equal(0, spy.callCount)
      assert.equal(1, Inbox_Authorize.authorize.callCount)
      assert.equal('code', Inbox_Authorize.authorize.getCall(0).args[0])
      Inbox_Authorize.authorize.getCall(0).args[1]({name: 'f l'})
      assert.equal(1, login._user_create.callCount)
      assert.deepEqual({name: 'f l', inbox_uid: 'code', language: 'lv'}, login._user_create.getCall(0).args[0])
      login._user_create.getCall(0).args[1]({id: 5})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5}, spy.getCall(0).args[0])

    it 'api call (error)', ->
      login.authorize({code: 'code', language: 'lv'}, spy)
      login._user_get.getCall(0).args[1](null)
      Inbox_Authorize.authorize.getCall(0).args[2]('error')
      assert.equal(0, login._user_create.callCount)
      assert.equal(1, spy.callCount)
      assert.deepEqual(null, spy.getCall(0).args[0])

    it 'buy', ->
      login.buy({service: 1, user_id: 333, language: 'ru'}, spy)
      assert.equal(1, Inbox_Authorize.transaction_create.callCount)
      assert.equal(70, Inbox_Authorize.transaction_create.getCall(0).args[0])
      assert.equal('ru', Inbox_Authorize.transaction_create.getCall(0).args[1])
      Inbox_Authorize.transaction_create.getCall(0).args[2]({id: '5', link: 'li'})
      assert.equal(1, login._transaction_create.callCount)
      assert.deepEqual({user_id: 333, service: 1, transaction_id: '5'}, login._transaction_create.getCall(0).args[0])
      assert.equal(0, spy.callCount)
      login._transaction_create.getCall(0).args[1](65)
      assert.equal(1, spy.callCount)
      assert.deepEqual({link: 'li'}, spy.getCall(0).args[0])

    it 'buy (no transaction)', ->
      login.buy({service: 4, user_id: 333, language: 'ru'}, spy)
      assert.equal(0, Inbox_Authorize.transaction_create.callCount)

    it 'buy_complete', ->
      login.buy_complete('22', 'a', 'b')
      assert.equal(1, login._transaction_get.callCount)
      assert.deepEqual({transaction_id: '22'}, login._transaction_get.getCall(0).args[0])
      assert.equal('a', login._transaction_get.getCall(0).args[1])
      assert.equal('b', login._transaction_get.getCall(0).args[2])
