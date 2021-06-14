events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


TestFacebook = {}

TestDraugiem_authrorize = null


Facebook_Authorize =
  constructor: ->
  _authorize_facebook: null
  _instant_validate: null
  _instant_get_encoded_data: null
  _signed_request_validate: null
  _signed_request_parse: null
Google_Authorize =
  authorize: null
Apple_Authorize =
  constructor: ->
  authorize: null
Inbox_Authorize =
  constructor: ->
  authorize: null
  transaction_create: null

config = {}
config_callbacks = []
uuid_v4 = ->
pbkdf2Sync = ->
Authorize = proxyquire '../authorize',
  '../api/draugiem':
    ApiDraugiem: class ApiDraugiem
      authorize: ->
        TestDraugiem_authrorize.apply(@, arguments)
        @app_key = 'auth'
  'fbgraph': TestFacebook
  '../api/facebook':
    ApiFacebook: class ApiFacebook
      constructor: -> Facebook_Authorize.constructor.apply(@, arguments)
      _authorize_facebook: -> Facebook_Authorize._authorize_facebook.apply(@, arguments)
      _instant_validate: -> Facebook_Authorize._instant_validate.apply(@, arguments)
      _instant_get_encoded_data: -> Facebook_Authorize._instant_get_encoded_data.apply(@, arguments)
      _signed_request_validate: -> Facebook_Authorize._signed_request_validate.apply(@, arguments)
      _signed_request_parse: -> Facebook_Authorize._signed_request_parse.apply(@, arguments)
  '../api/google':
    ApiGoogle: class ApiGoogle
      authorize: -> Google_Authorize.authorize.apply(@, arguments)
  '../api/apple':
    ApiApple: class ApiApple
      constructor: -> Apple_Authorize.constructor.apply(@, arguments)
      authorize: -> Apple_Authorize.authorize.apply(@, arguments)
  '../api/inbox':
    ApiInbox: class ApiInbox
      constructor: -> Inbox_Authorize.constructor.apply(@, arguments)
      authorize: -> Inbox_Authorize.authorize.apply(@, arguments)
      transaction_create: -> Inbox_Authorize.transaction_create.apply(@, arguments)
  '../../config':
    config_get: (param)-> config[param]
    config_callback: (c)-> config_callbacks.push c
  'uuid':
    v4: -> uuid_v4()
  'crypto':
    pbkdf2Sync: -> pbkdf2Sync.apply(@, arguments)

LoginDraugiem = Authorize.draugiem
LoginFacebook = Authorize.facebook
LoginGoogle = Authorize.google
LoginApple = Authorize.apple
LoginInbox = Authorize.inbox
LoginCordova = Authorize.cordova
LoginEmail = Authorize.email
Login = Authorize.Login


describe 'Athorize', ->
  spy = null
  spy2 = null
  clock = null
  db = {}
  beforeEach ->
    clock = sinon.useFakeTimers()
    config =
      draugiem:
        buy_transaction:
          1: 444
        buy_price:
          1: 1400
      inbox:
        buy_price:
          1: 70
      google:
        id: 'gid'
      apple:
        id: 'apid'
      facebook:
        id: 'fid'
        key: 'fkey'
        buy_price:
          2: 70
      email:
        salt: 'salt1'
        sha: 'sh'
      buy:
        product:
          '1': 50
        subscription:
          '11': 'sub'
      db: db
    Login::_opt.language.validate = ->
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


    it '_parse', ->
      login._opt =
        'some':
          parse: 'p'
      assert.deepEqual [ ['some', 'p'] ], login._parse()

    it '_opt', ->
      assert.deepEqual {db: true, public: true}, login._opt.id
      assert.equal true, login._opt.language.db
      assert.deepEqual {db: true}, login._opt.draugiem_uid
      assert.deepEqual {db: true}, login._opt.facebook_uid
      assert.deepEqual {db: true}, login._opt.google_uid
      assert.deepEqual {db: true}, login._opt.inbox_uid
      assert.deepEqual {db: true}, login._opt.apple_uid
      assert.deepEqual {db: true, default: '', public: true}, login._opt.img
      assert.deepEqual {}, login._opt.new
      assert.equal true, login._opt.date_joined.db
      assert.equal true, new Date().getTime() - 10 < login._opt.date_joined.default() < new Date().getTime() + 10
      assert.equal true, login._opt.last_login.db
      assert.equal true, new Date().getTime() - 10 < login._opt.last_login.default() < new Date().getTime() + 10
      assert.equal 'Raccoon', login._opt.name.default


    it '_opt name validate', ->
      assert.equal 'Raccoon', login._opt.name.validate(null, {})
      assert.equal 'Raccoon 5', login._opt.name.validate('', {id: 5})
      assert.equal 'Raccoon 5', login._opt.name.validate('Raccoon', {id: 5})
      assert.equal 'n', login._opt.name.validate('n', {id: 5})


    describe '_opt_defaults', ->
      beforeEach ->
        login._opt =
          img: {}
          name:
            default: 'Some'

      it 'default', ->
        assert.deepEqual {name: 'name'}, login._opt_defaults({name: 'name'})
        assert.deepEqual {name: ''}, login._opt_defaults({name: ''})
        assert.deepEqual {name: 'Some'}, login._opt_defaults({name: null})

      it 'no default', ->
        assert.deepEqual {img: ''}, login._opt_defaults({img: ''})

      it 'default function', ->
        login._opt.name.default = fake = sinon.fake.returns 'n1'
        assert.deepEqual {name: 'n1', id: 5}, login._opt_defaults({name: null, id: 5})
        assert.equal 1, fake.callCount
        assert.deepEqual {id: 5}, fake.getCall(0).args[0]

      it 'validate', ->
        login._opt.name.validate = fake = sinon.fake.returns 'v1'
        assert.deepEqual {id: 5, name: 'v1'}, login._opt_defaults({name: 'n5', id: 5})
        assert.equal 1, fake.callCount
        assert.equal 'n5', fake.getCall(0).args[0]
        assert.deepEqual {id: 5}, fake.getCall(0).args[1]

      it 'db', ->
        assert.deepEqual {}, login._opt_defaults({name: 'name'}, true)
        login._opt.name.db = true
        assert.deepEqual {name: 'name'}, login._opt_defaults({name: 'name'}, true)


    describe '_user_get', ->
      beforeEach ->
        login._parse = sinon.fake.returns 'p'
        login._opt =
          id:
            db: true
          name:
            db: true
          img: {}
        login._opt_defaults = sinon.fake.returns {id: 5, name: 'val'}
        login._user_update = sinon.spy()

      it 'default', ->
        login._user_get({id: 5}, spy)
        assert.equal(1, db.select_one.callCount)
        assert.deepEqual ['id', 'name'], db.select_one.getCall(0).args[0].select
        assert.equal('auth_user', db.select_one.getCall(0).args[0].table)
        assert.deepEqual({id: 5}, db.select_one.getCall(0).args[0].where)
        assert.equal('p', db.select_one.getCall(0).args[0].parse)
        db.select_one.getCall(0).args[1]({id: 5, d: 't'})
        assert.equal 1, login._opt_defaults.callCount
        assert.deepEqual {id: 5, d: 't', new: false, last_login: null}, login._opt_defaults.getCall(0).args[0]
        assert.equal 1, login._user_update.callCount
        assert.deepEqual {id: 5, name: 'val'}, login._user_update.getCall(0).args[0]
        assert.equal(1, spy.callCount)
        assert.deepEqual({id: 5, name: 'val'}, spy.getCall(0).args[0])

      it 'not found', ->
        login._user_get({id: 5}, spy)
        db.select_one.getCall(0).args[1](null)
        assert.equal(1, spy.callCount)
        assert.equal(null, spy.getCall(0).args[0])
        assert.equal(0, db.update.callCount)

      it 'additional update', ->
        login._user_get({id: 5}, {facebook: '10'}, spy)
        db.select_one.getCall(0).args[1]({id: 5, facebook: '5'})
        assert.equal '10', login._opt_defaults.getCall(0).args[0].facebook


    describe '_user_create', ->
      beforeEach ->
        login._opt =
          empty: {}
          new: {default: true}
          name:
            db: true
          default:
            db: true
            default: ''
          defaultover:
            db: true
            default: 'over'
        login._opt_defaults = sinon.fake.returns {name: 'validated'}
        login._parse = sinon.fake.returns 'p'
        login._user_update = sinon.spy()

      it 'default', ->
        login._user_create({name: 'name', defaultover: 'de'}, spy)
        assert.equal 1, login._opt_defaults.callCount
        assert.deepEqual {default: null, name: 'name', defaultover: 'de'}, login._opt_defaults.getCall(0).args[0]
        assert.equal true, login._opt_defaults.getCall(0).args[1]
        assert.equal(1, db.insert.callCount)
        assert.equal('auth_user', db.insert.getCall(0).args[0].table)
        assert.deepEqual {name: 'validated'}, db.insert.getCall(0).args[0].data
        assert.equal('p', db.insert.getCall(0).args[0].parse)
        assert.equal 1, login._parse.callCount
        login._opt_defaults = sinon.fake.returns {name: 'nnew', id: 2}
        db.insert.getCall(0).args[1](2)
        assert.equal 1, login._opt_defaults.callCount
        assert.deepEqual {name: 'validated', id: 2, new: true}, login._opt_defaults.getCall(0).args[0]
        assert.equal 1, spy.callCount
        assert.deepEqual {name: 'nnew', id: 2}, spy.getCall(0).args[0]
        assert.equal 1, login._user_update.callCount
        assert.deepEqual {name: 'nnew', id: 2}, login._user_update.getCall(0).args[0]


    describe '_user_update', ->
      beforeEach ->
        login._opt_defaults = sinon.fake.returns {name: 'n', id: 3}
        login._parse = sinon.fake.returns 'p'

      it 'default', ->
        login._user_update({name: 's', id: 3})
        assert.equal 1, login._opt_defaults.callCount
        assert.deepEqual {name: 's', id: 3}, login._opt_defaults.getCall(0).args[0]
        assert.equal true, login._opt_defaults.getCall(0).args[1]
        assert.equal(1, db.update.callCount)
        assert.equal('auth_user', db.update.getCall(0).args[0].table)
        assert.deepEqual({id: 3}, db.update.getCall(0).args[0].where)
        assert.deepEqual({name: 'n'}, db.update.getCall(0).args[0].data)
        assert.equal('p', db.update.getCall(0).args[0].parse)
        assert.equal 1, login._parse.callCount

      it 'no update data', ->
        login._opt_defaults = sinon.fake.returns {id: 3}
        login._user_update({name: 's', id: 3})
        assert.equal(0, db.update.callCount)


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


    it 'db check (null)', ->
      login._table_session = 's_table'
      login._user_get = sinon.spy()
      login._user_session_check('cd', spy)
      assert.equal(1, db.select_one.callCount)
      assert.deepEqual({
        table: 's_table'
        where: {code: 'cd', last_updated: {date: -30} }
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

    it '_transaction_get', ->
      login._table_transaction = 's_trans'
      login._transaction_get({id: 'pr'}, spy, spy2)
      assert.equal(1, db.select_one.callCount)
      assert.equal('s_trans', db.select_one.getCall(0).args[0].table)
      assert.deepEqual({id: 'pr'}, db.select_one.getCall(0).args[0].where)
      db.select_one.getCall(0).args[1]({id: 'z', fulfill: 0, user_id: 2, service: '1'})
      assert.equal(1, spy.callCount)
      assert.equal(2, spy.getCall(0).args[0].user_id)
      assert.equal('z', spy.getCall(0).args[0].transaction.id)
      spy.getCall(0).args[0].complete()
      assert.equal(1, db.update.callCount)
      assert.equal('s_trans', db.update.getCall(0).args[0].table)
      assert.deepEqual({id: 'z'}, db.update.getCall(0).args[0].where)
      assert.deepEqual({fulfill: 1, fulfilled: new Date()}, db.update.getCall(0).args[0].data)
      db.update.getCall(0).args[1]()
      assert.equal(1, spy2.callCount)
      assert.equal(null, spy2.getCall(0).args[0])

    it '_transaction_get (fulfilled subscription)', ->
      login._transaction_get({id: 'pr'}, spy, spy2)
      db.select_one.getCall(0).args[1]({id: 'z', fulfill: 1, user_id: 2, service: '11'})
      spy.getCall(0).args[0].complete()
      assert.equal(2, db.update.getCall(0).args[0].data.fulfill)

    it '_transaction_get (fulfilled coins)', ->
      login._transaction_get({id: 'pr'}, spy, spy2)
      db.select_one.getCall(0).args[1]({id: 'z', fulfill: 1, user_id: 2, service: '1'})
      assert.equal(0, spy.callCount)
      assert.equal(1, spy2.callCount)
      assert.notEqual(null, spy2.getCall(0).args[0])

    it '_transaction_get (fulfilled subscriptions empty)', ->
      config.buy.subscription = null
      login._transaction_get({id: 'pr'}, spy, spy2)
      db.select_one.getCall(0).args[1]({id: 'z', fulfill: 1, user_id: 2, service: '11'})
      assert.equal(0, spy.callCount)
      assert.equal(1, spy2.callCount)
      assert.notEqual(null, spy2.getCall(0).args[0])

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
      assert.deepEqual({code: 'code'}, login._api_call.getCall(0).args[0])
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

    it 'new update (with language)', ->
      login.authorize({code: 'code', language: 'ru'}, spy)
      login._user_session_check.getCall(0).args[1](null)
      login._api_call.getCall(0).args[1]({fb: '56'}, {name: 'n', img: 'im'})
      assert.deepEqual({
        name: 'n'
        img: 'im'
        language: 'ru'
      }, login._user_create_or_update.getCall(0).args[1])

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
      assert.equal('draugiem', login._name)

    it 'success', ->
      login._api_call({'code'}, spy)
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
      assert.equal(984, spy_tr.getCall(0).args[1])
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
    payment_subscription_success = null
    spy2 = null
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
      payment_subscription_success = {
        "status": "active",
        "next_period_product": "https://zole.raccoons.lv/d/og/service-11-lv.html",
        "next_bill_time": "2020-04-26T15:23:17+0000",
        "user": {
          "name": "Sarah Aldicehaiebda Wisemanescu",
          "id": "102338228088117"
        },
        "id": "301663523297285"
      }
      login = new LoginFacebook()
      login._transaction_create = sinon.spy()
      login._transaction_get = sinon.spy()
      Google_Authorize.authorize = sinon.spy()
      login._user_get = sinon.spy()
      login._user_update = sinon.spy()
      Facebook_Authorize._authorize_facebook = sinon.spy()
      Facebook_Authorize._instant_validate = sinon.fake.returns true
      Facebook_Authorize._instant_get_encoded_data = sinon.fake.returns {facebook_uid: '5', name: 'n', img: 'i', language: 'ru'}
      spy2 = sinon.spy()
      Login::authorize = -> spy2.apply(@, arguments)
      login._user_create_or_update = sinon.spy()

    it 'default', ->
      assert.equal('auth_user_session_facebook', login._table_session)
      assert.equal('transaction_facebook', login._table_transaction)
      assert.equal('deletion_facebook', login._table_deletion)
      assert.equal('facebook', login._name)

    it 'authorize (facebook instant)', ->
      login.authorize({code: 'code'}, spy)
      assert.equal 0, spy2.callCount
      assert.equal 1, Facebook_Authorize._instant_validate.callCount
      assert.equal 'code', Facebook_Authorize._instant_validate.getCall(0).args[0]
      assert.equal 1, Facebook_Authorize._instant_get_encoded_data.callCount
      assert.equal 'code', Facebook_Authorize._instant_get_encoded_data.getCall(0).args[0]
      assert.equal 1, login._user_create_or_update.callCount
      assert.deepEqual {facebook_uid: '5'}, login._user_create_or_update.getCall(0).args[0]
      assert.deepEqual {name: 'n', img: 'i', language: 'ru'}, login._user_create_or_update.getCall(0).args[1]
      login._user_create_or_update.getCall(0).args[2]({u: 'ser'})
      assert.equal 1, spy.callCount
      assert.deepEqual {u: 'ser'}, spy.getCall(0).args[0]

    it 'authorize (facebook instant invalid)', ->
      Facebook_Authorize._instant_get_encoded_data = sinon.fake.returns null
      login.authorize({code: 'code'}, spy)
      assert.equal 0, login._user_create_or_update.callCount
      assert.equal 1, spy.callCount
      assert.equal null, spy.getCall(0).args[0]

    it 'authorize (facebook not instant)', ->
      Facebook_Authorize._instant_validate = sinon.fake.returns false
      login.authorize({code: 'code'}, spy)
      assert.equal 0, Facebook_Authorize._instant_get_encoded_data.callCount
      assert.equal 1, spy2.callCount
      assert.deepEqual {code: 'code'}, spy2.getCall(0).args[0]
      assert.deepEqual spy, spy2.getCall(0).args[1]

    it 'success', ->
      login._api_call({code: 'code'}, spy)
      assert.equal(1, Facebook_Authorize._authorize_facebook.callCount)
      assert.equal('code', Facebook_Authorize._authorize_facebook.getCall(0).args[0])
      Facebook_Authorize._authorize_facebook.getCall(0).args[1]({facebook_uid: '5', name: 'n', facebook_token_for_business: 'tk', img: 'im', language: 'lg'})
      assert.equal(1, spy.callCount)
      assert.deepEqual({facebook_uid: '5'}, spy.getCall(0).args[0])
      assert.deepEqual({name: 'n', language: 'lg', facebook_token_for_business: 'tk', img: 'im'}, spy.getCall(0).args[1])

    it 'error', ->
      login._api_call('code', spy)
      Facebook_Authorize._authorize_facebook.getCall(0).args[1](null)
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])

    it 'buy', ->
      login.buy({user_id: 5, service: 2}, spy)
      assert.equal(1, login._transaction_create.callCount)
      assert.deepEqual({service: 2, user_id: 5}, login._transaction_create.getCall(0).args[0])
      login._transaction_create.getCall(0).args[1]({id: 10})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 10}, spy.getCall(0).args[0])

    it 'buy (no transaction)', ->
      login.buy({user_id: 5, service: 1}, spy)
      assert.equal(0, login._transaction_create.callCount)

    it 'buy_complete', ->
      login.buy_complete {id: '33'}, 'a', 'b'
      assert.equal(1, TestFacebook.get.callCount)
      assert.equal('/33?fields=request_id,user,actions,items&access_token=fid|fkey', TestFacebook.get.getCall(0).args[0])
      TestFacebook.get.getCall(0).args[1](null, payment_success)
      assert.equal(1, login._transaction_get.callCount)
      assert.deepEqual({id: '3'}, login._transaction_get.getCall(0).args[0])
      assert.equal('a', login._transaction_get.getCall(0).args[1])
      assert.equal('b', login._transaction_get.getCall(0).args[2])

    it 'buy_complete (err)', ->
      login.buy_complete {id: '33'}, 'a', spy
      TestFacebook.get.getCall(0).args[1]('err')
      assert.equal(0, login._transaction_get.callCount)
      assert.equal(1, spy.callCount)
      assert.equal('err', spy.getCall(0).args[0])

    it 'buy_complete (failure)', ->
      login.buy_complete {id: '33'}, 'a', spy
      TestFacebook.get.getCall(0).args[1](null, payment_failed)
      assert.equal(0, login._transaction_get.callCount)
      assert.equal(1, spy.callCount)
      assert.equal('incompleted', spy.getCall(0).args[0])

    it 'buy_complete (subscription)', ->
      clock.tick new Date('2020-04-20').getTime()
      login.buy_complete {id: '22', subscription: true}, spy, spy2
      assert.equal(1, TestFacebook.get.callCount)
      assert.equal('/22?fields=status,next_period_product,next_bill_time,user&access_token=fid|fkey', TestFacebook.get.getCall(0).args[0])
      TestFacebook.get.getCall(0).args[1](null, payment_subscription_success)
      assert.equal(0, login._transaction_get.callCount)
      assert.equal 1, login._user_get.callCount
      assert.deepEqual({facebook_uid: '102338228088117'}, login._user_get.getCall(0).args[0])
      login._user_get.getCall(0).args[1]({facebook_subscriptions: {5: '1234'}, id: 3})
      assert.equal 1, login._user_update.callCount
      assert.deepEqual {id: 3, facebook_subscriptions: {5: '1234', 11: '22'}}, login._user_update.getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.deepEqual {service: '11', expire: 7}, spy.getCall(0).args[0].transaction
      assert.equal 3, spy.getCall(0).args[0].user_id
      spy.getCall(0).args[0].complete()
      assert.equal 1, spy2.callCount

    it 'buy_complete (subscription - outdated)', ->
      clock.tick new Date('2020-05-20').getTime()
      login.buy_complete {id: '22', subscription: true}, spy, spy2
      TestFacebook.get.getCall(0).args[1](null, payment_subscription_success)
      login._user_get.getCall(0).args[1]({facebook_subscriptions: {5: '1234'}, id: 3})
      assert.equal 0, spy.callCount
      assert.equal 1, spy2.callCount

    it 'buy_complete (subscription - not exist)', ->
      login.buy_complete {id: '22', subscription: true}, spy, spy2
      TestFacebook.get.getCall(0).args[1](null, payment_subscription_success)
      login._user_get.getCall(0).args[1]({facebook_subscriptions: null, id: 3})
      assert.equal 1, login._user_update.callCount
      assert.deepEqual {11: '22'}, login._user_update.getCall(0).args[0].facebook_subscriptions

    it 'buy_complete (subscription - already exist)', ->
      login.buy_complete {id: '22', subscription: true}, spy, spy2
      TestFacebook.get.getCall(0).args[1](null, payment_subscription_success)
      login._user_get.getCall(0).args[1]({facebook_subscriptions: {11: '22'}, id: 3})
      assert.equal 0, login._user_update.callCount

    it 'buy_complete (subscription - no service)', ->
      login.buy_complete {id: '22', subscription: true}, spy, spy2
      payment_subscription_success.next_period_product = 'super-ptoru'
      TestFacebook.get.getCall(0).args[1](null, payment_subscription_success)
      login._user_get.getCall(0).args[1]({facebook_subscriptions: {11: '22'}, id: 3})
      assert.equal 0, login._user_update.callCount
      assert.equal 0, spy.callCount
      assert.equal 1, spy2.callCount
      assert.equal 'service error: super-ptoru', spy2.getCall(0).args[0]

    it 'buy_complete (subscription - service not found)', ->
      login.buy_complete {id: '22', subscription: true}, spy, spy2
      payment_subscription_success.next_period_product = '/service-45-lv.html'
      TestFacebook.get.getCall(0).args[1](null, payment_subscription_success)
      login._user_get.getCall(0).args[1]({facebook_subscriptions: {11: '22'}, id: 3})
      assert.equal 1, login._user_update.callCount
      assert.equal 0, spy.callCount
      assert.equal 1, spy2.callCount
      assert.equal 'service not found: 45', spy2.getCall(0).args[0]

    it 'buy_complete (subscription - no user)', ->
      login.buy_complete {id: '22', subscription: true}, spy, spy2
      TestFacebook.get.getCall(0).args[1](null, payment_subscription_success)
      login._user_get.getCall(0).args[1](null)
      assert.equal 0, login._user_update.callCount
      assert.equal 0, spy.callCount
      assert.equal 1, spy2.callCount
      assert.equal 'user not found: 102338228088117', spy2.getCall(0).args[0]

    it 'buy_complete (subscription - status not active)', ->
      login.buy_complete {id: '22', subscription: true}, spy, spy2
      payment_subscription_success.status = 'failed'
      TestFacebook.get.getCall(0).args[1](null, payment_subscription_success)
      assert.equal 0, login._user_get.callCount
      assert.equal 0, spy.callCount
      assert.equal 1, spy2.callCount
      assert.equal 'status not active', spy2.getCall(0).args[0]

    it 'buy_complete (subscription - no user id)', ->
      login.buy_complete {id: '22', subscription: true}, 'a', spy
      delete payment_subscription_success.user
      TestFacebook.get.getCall(0).args[1](null, payment_subscription_success)
      assert.equal 0, login._user_get.callCount
      assert.equal(1, spy.callCount)
      assert.equal('user is missing', spy.getCall(0).args[0])


    describe 'deletion_request', ->
      beforeEach ->
        Facebook_Authorize._signed_request_validate = sinon.fake.returns true
        Facebook_Authorize._signed_request_parse = sinon.fake.returns {
          user_id: 'fbu1',
          algorithm: 'HMAC-SHA256',
          issued_at: 1621944556
        }
        login._user_get = sinon.spy()
        uuid_v4 = sinon.fake.returns 'rnd'

      it 'default', ->
        login.deletion_request('req', spy)
        assert.equal 1, Facebook_Authorize._signed_request_validate.callCount
        assert.equal 'req', Facebook_Authorize._signed_request_validate.getCall(0).args[0]
        assert.equal 1, Facebook_Authorize._signed_request_parse.callCount
        assert.equal 'req', Facebook_Authorize._signed_request_parse.getCall(0).args[0]
        assert.equal 1, login._user_get.callCount
        assert.deepEqual {facebook_uid: 'fbu1'}, login._user_get.getCall(0).args[0]
        login._user_get.getCall(0).args[1]({id: 5})
        assert.equal 1, db.select_one.callCount
        assert.equal 'deletion_facebook', db.select_one.getCall(0).args[0].table
        assert.deepEqual ['status', 'code'], db.select_one.getCall(0).args[0].select
        assert.deepEqual {user_id: 5}, db.select_one.getCall(0).args[0].where
        db.select_one.getCall(0).args[1](null)
        assert.equal 1, db.insert.callCount
        assert.equal 'deletion_facebook', db.insert.getCall(0).args[0].table
        assert.equal true, db.insert.getCall(0).args[0].data.initiated <= new Date()
        assert.equal 5, db.insert.getCall(0).args[0].data.user_id
        assert.equal 5, db.insert.getCall(0).args[0].data.user_id
        assert.equal 'Initiated', db.insert.getCall(0).args[0].data.status
        assert.equal 'rnd', db.insert.getCall(0).args[0].data.code
        assert.equal 1, uuid_v4.callCount
        db.insert.getCall(0).args[1]()
        assert.equal 1, spy.callCount
        assert.deepEqual {status: 'Initiated', code: 'rnd'}, spy.getCall(0).args[0]

      it 'signed_request invalid', ->
        Facebook_Authorize._signed_request_validate = -> false
        login.deletion_request('req', spy)
        assert.equal 0, Facebook_Authorize._signed_request_parse.callCount
        assert.equal 0, login._user_get.callCount
        assert.equal 1, spy.callCount
        assert.equal null, spy.getCall(0).args[0]

      it 'signed_request no user_id', ->
        Facebook_Authorize._signed_request_parse = -> {}
        login.deletion_request('req', spy)
        assert.equal 0, login._user_get.callCount
        assert.equal 1, spy.callCount
        assert.equal null, spy.getCall(0).args[0]

      it 'signed_request no data', ->
        Facebook_Authorize._signed_request_parse = -> null
        login.deletion_request('req', spy)
        assert.equal 0, login._user_get.callCount
        assert.equal 1, spy.callCount
        assert.equal null, spy.getCall(0).args[0]

      it 'user not found', ->
        login.deletion_request('req', spy)
        login._user_get.getCall(0).args[1](null)
        assert.equal 0, db.select_one.callCount
        assert.equal 1, spy.callCount
        assert.equal null, spy.getCall(0).args[0]

      it 'result found', ->
        login.deletion_request('req', spy)
        login._user_get.getCall(0).args[1]({id: 5})
        db.select_one.getCall(0).args[1]({status: 'Init', code: 'cd'})
        assert.equal 1, spy.callCount
        assert.deepEqual {status: 'Init', code: 'cd'}, spy.getCall(0).args[0]
        assert.equal 0, db.insert.callCount


    it 'deletion_status', ->
      login.deletion_status('cd', spy)
      assert.equal 1, db.select_one.callCount
      assert.equal 'deletion_facebook', db.select_one.getCall(0).args[0].table
      assert.deepEqual ['status'], db.select_one.getCall(0).args[0].select
      assert.deepEqual {code: 'cd'}, db.select_one.getCall(0).args[0].where
      db.select_one.getCall(0).args[1]({status: 'init'})
      assert.equal 1, spy.callCount
      assert.deepEqual {status: 'init'}, spy.getCall(0).args[0]

    it 'deletion_status (not found)', ->
      login.deletion_status('cd', spy)
      db.select_one.getCall(0).args[1](null)
      assert.equal null, spy.getCall(0).args[0]


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

    it 'no uid', ->
      login._api_call('code', spy)
      Google_Authorize.authorize.getCall(0).args[1]({name: 'n'})
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])

    it 'error', ->
      login._api_call('code', spy)
      Google_Authorize.authorize.getCall(0).args[1](null)
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])


  describe 'LoginApple', ->
    login = null
    beforeEach ->
      login = new LoginApple()
      Apple_Authorize.authorize = sinon.spy()

    it 'default', ->
      assert.equal('auth_user_session_apple', login._table_session)

    it 'success', ->
      login._api_call({language: 'lg'}, spy)
      assert.equal(1, Apple_Authorize.authorize.callCount)
      assert.deepEqual({language: 'lg'}, Apple_Authorize.authorize.getCall(0).args[0])
      Apple_Authorize.authorize.getCall(0).args[1]({uid: 'as', name: 'n'})
      assert.equal(1, spy.callCount)
      assert.deepEqual({apple_uid: 'as'}, spy.getCall(0).args[0])
      assert.deepEqual({name: 'n', language: 'lg'}, spy.getCall(0).args[1])

    it 'success (no name)', ->
      login._api_call({language: 'lg'}, spy)
      Apple_Authorize.authorize.getCall(0).args[1]({uid: 'as'})
      assert.equal(1, spy.callCount)
      assert.deepEqual({apple_uid: 'as'}, spy.getCall(0).args[0])
      assert.deepEqual({language: 'lg'}, spy.getCall(0).args[1])

    it 'no uid', ->
      login._api_call('code', spy)
      Apple_Authorize.authorize.getCall(0).args[1]({name: 'n'})
      assert.equal(1, spy.callCount)
      assert.equal(null, spy.getCall(0).args[0])

    it 'error', ->
      login._api_call('code', spy)
      Apple_Authorize.authorize.getCall(0).args[1](null)
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
      assert.equal('inbox', login._name)

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
      Inbox_Authorize.transaction_create.getCall(0).args[2]({id: '5', link: 'li', language: 'ru'})
      assert.equal(1, login._transaction_create.callCount)
      assert.deepEqual({user_id: 333, service: 1, language: 'ru', transaction_id: '5'}, login._transaction_create.getCall(0).args[0])
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


  describe 'LoginCordova', ->
    login = null
    beforeEach ->
      login = new LoginCordova()
      login._transaction_get = sinon.spy()
      login._transaction_create = sinon.spy()

    it 'default', ->
      assert.equal('transaction_cordova', login._table_transaction)

    it 'buy_complete', ->
      login.buy_complete 'prms', 'cbck', spy
      assert.equal 1, login._transaction_get.callCount
      assert.equal 'prms', login._transaction_get.getCall(0).args[0]
      assert.equal 'cbck', login._transaction_get.getCall(0).args[1]
      login._transaction_get.getCall(0).args[2]('mess')
      assert.equal 1, spy.callCount
      assert.equal 'mess', spy.getCall(0).args[0]

    it 'buy_complete (transaction not found)', ->
      login.buy_complete 'prms', 'cbck', spy
      login._transaction_get.getCall(0).args[2]('transaction not found')
      assert.equal 0, spy.callCount
      assert.equal 1, login._transaction_create.callCount
      assert.equal 'prms', login._transaction_create.getCall(0).args[0]
      login._transaction_create.getCall(0).args[1]({id: '5'})
      assert.equal 2, login._transaction_get.callCount
      assert.deepEqual {id: '5'}, login._transaction_get.getCall(1).args[0]
      assert.equal 'cbck', login._transaction_get.getCall(1).args[1]
      assert.deepEqual spy, login._transaction_get.getCall(1).args[2]


  describe 'LoginEmail', ->
    login = null
    beforeEach ->
      login = new LoginEmail()
      login._user_get = sinon.spy()
      login._user_session_check = sinon.spy()
      login._user_session_save = sinon.spy()
      login._user_update = sinon.spy()
      uuid_v4 = sinon.fake.returns 'uuid'
      pbkdf2Sync = sinon.fake.returns Buffer.from('2')

    it 'default', ->
      assert.equal 'email', login._name
      assert.equal 'auth_user_session_email', login._table_session

    it '_update_password', ->
      login._password = sinon.fake.returns 'pass'
      login._update_password {id: 5, password: 'pa'}
      assert.equal 1, login._password.callCount
      assert.equal 'pa', login._password.getCall(0).args[0]
      assert.equal 1, login._user_update.callCount
      assert.deepEqual {id: 5, password: 'pass'}, login._user_update.getCall(0).args[0]

    it '_check_email', ->
      login._check_email({email: 'b'}, spy)
      assert.equal 1, login._user_get.callCount
      assert.deepEqual {email: 'b'}, login._user_get.getCall(0).args[0]
      assert.deepEqual spy, login._user_get.getCall(0).args[1]

    it '_password', ->
      assert.equal '32', login._password('ps')
      assert.equal 1, pbkdf2Sync.callCount
      assert.equal 'ps', pbkdf2Sync.getCall(0).args[0]
      assert.equal 'salt1', pbkdf2Sync.getCall(0).args[1]
      assert.equal 4096, pbkdf2Sync.getCall(0).args[2]
      assert.equal 16, pbkdf2Sync.getCall(0).args[3]
      assert.equal 'sh', pbkdf2Sync.getCall(0).args[4]

    it 'authorize', ->
      login.authorize {code: '5-12'}, spy
      assert.equal 1, login._user_session_check.callCount
      assert.equal '5-12', login._user_session_check.getCall(0).args[0]
      login._user_session_check.getCall(0).args[1]( {id: 2, password: 'pass'} )
      assert.equal 1, spy.callCount
      assert.deepEqual {id: 2, password: 'pass'}, spy.getCall(0).args[0]

    it 'email/pass', ->
      login._password = sinon.fake.returns 'p1'
      login.authorize {code: ['e@ma.il', 'pass']}, spy
      assert.equal 0, login._user_session_check.callCount
      assert.equal 1, login._user_get.callCount
      assert.deepEqual {email: 'e@ma.il'}, login._user_get.getCall(0).args[0]
      login._user_get.getCall(0).args[1]({password: 'p1', id: 5})
      assert.equal 1, login._password.callCount
      assert.equal 'pass', login._password.getCall(0).args[0]
      assert.equal 1, login._user_session_save.callCount
      assert.deepEqual {user_id: 5, code: '5-uuid'}, login._user_session_save.getCall(0).args[0]
      assert.equal 1, uuid_v4.callCount
      assert.equal 1, spy.callCount
      assert.deepEqual {id: 5, password: 'p1'}, spy.getCall(0).args[0]
      assert.equal '5-uuid', spy.getCall(0).args[1]

    it 'email not found', ->
      login._password = sinon.fake.returns 'p1'
      login.authorize {code: ['e@ma.il', 'pass']}, spy
      login._user_get.getCall(0).args[1](null)
      assert.equal 0, login._password.callCount
      assert.equal null, spy.getCall(0).args[0]

    it 'pass wrong', ->
      login._password = sinon.fake.returns 'p2'
      login.authorize {code: ['e@ma.il', 'pass']}, spy
      login._user_get.getCall(0).args[1]({password: 'p1', id: 5})
      assert.equal null, spy.getCall(0).args[0]
