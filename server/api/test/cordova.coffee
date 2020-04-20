assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')

verifyPayment = ->
ValidatorGoogle_constructor = ->
ValidatorGoogle_verify = ->
Cordova = proxyquire('../cordova', {
  'iap': {
    verifyPayment: -> verifyPayment.apply(@, arguments)
  }
  './cordova.google': class ValidatorGoogle
    constructor: -> ValidatorGoogle_constructor.apply(@, arguments)
    verify: -> ValidatorGoogle_verify.apply(@, arguments)
})


describe 'cordova', ->
  spy = null
  o = null
  params = null
  clock = null
  beforeEach ->
    clock = sinon.useFakeTimers()
    spy = sinon.spy()
    params = {android: {email: 'em', key: 'ke', packageName: 'pck'}, ios: {shared_secret: 'shs'}}
    ValidatorGoogle_constructor = sinon.spy()
    o = new Cordova(params)

  afterEach ->
    clock.restore()

  it 'constructor', ->
    assert.equal 1, ValidatorGoogle_constructor.callCount
    assert.deepEqual params.android, ValidatorGoogle_constructor.getCall(0).args[0]


  describe 'payment_validate', ->
    success_ios = null
    success_android = null
    subscription_android = null
    subscription_ios = null
    beforeEach ->
      success_ios = {
        receipt: {
          receipt_type: 'ProductionSandbox',
          adam_id: 0,
          app_item_id: 0,
          bundle_id: 'com.raccoons.zole',
          application_version: '3.0.0',
          download_id: 0,
          version_external_identifier: 0,
          receipt_creation_date: '2020-03-04 20:25:37 Etc/GMT',
          receipt_creation_date_ms: '1583353537000',
          receipt_creation_date_pst: '2020-03-04 12:25:37 America/Los_Angeles',
          request_date: '2020-03-04 20:50:58 Etc/GMT',
          request_date_ms: '1583355058732',
          request_date_pst: '2020-03-04 12:50:58 America/Los_Angeles',
          original_purchase_date: '2013-08-01 07:00:00 Etc/GMT',
          original_purchase_date_ms: '1375340400000',
          original_purchase_date_pst: '2013-08-01 00:00:00 America/Los_Angeles',
          original_application_version: '1.0',
          in_app: []
        },
        latestReceiptInfo: null,
        latestExpiredReceiptInfo: null,
        productId: '50monetas2',
        transactionId: '1000000633801337',
        purchaseDate: 1583184628000,
        expirationDate: null,
        pendingRenewalInfo: null,
        environment: 'sandbox',
        platform: 'apple'
      }
      success_android = {
        kind: 'androidpublisher#productPurchase',
        purchaseTimeMillis: '1583373013055',
        purchaseState: 0,
        consumptionState: 0,
        developerPayload: '',
        orderId: 'GPA.3396-4053-7567-83173',
        purchaseType: 0,
        acknowledgementState: 0
      }
      subscription_android = {
       "kind": "androidpublisher#subscriptionPurchase",
       "startTimeMillis": "1583373661142",
       "expiryTimeMillis": "1583374215715",
       "autoRenewing": false,
       "priceCurrencyCode": "EUR",
       "priceAmountMicros": "8490000",
       "countryCode": "LV",
       "developerPayload": "",
       "cancelReason": 1,
       "orderId": "GPA.3398-1855-5167-65974..0",
       "purchaseType": 0,
       "acknowledgementState": 0
      }
      subscription_ios = {
        receipt: {
          receipt_type: 'ProductionSandbox',
          adam_id: 0,
          app_item_id: 0,
          bundle_id: 'com.raccoons.zole',
          application_version: '3.0.0',
          download_id: 0,
          version_external_identifier: 0,
          receipt_creation_date: '2020-03-05 14:05:48 Etc/GMT',
          receipt_creation_date_ms: '1583417148000',
          receipt_creation_date_pst: '2020-03-05 06:05:48 America/Los_Angeles',
          request_date: '2020-03-05 14:19:13 Etc/GMT',
          request_date_ms: '1583417953412',
          request_date_pst: '2020-03-05 06:19:13 America/Los_Angeles',
          original_purchase_date: '2013-08-01 07:00:00 Etc/GMT',
          original_purchase_date_ms: '1375340400000',
          original_purchase_date_pst: '2013-08-01 00:00:00 America/Los_Angeles',
          original_application_version: '1.0',
          in_app: [ [Object], [Object], [Object] ]
        },
        latestReceiptInfo: [],
        latestExpiredReceiptInfo: null,
        productId: 'vip5',
        transactionId: '1000000635313423',
        purchaseDate: 1583417745000,
        expirationDate: 1583418045000,
        pendingRenewalInfo: [
          {
            auto_renew_product_id: 'vip5',
            original_transaction_id: '1000000635308379',
            product_id: 'vip5',
            auto_renew_status: '1'
          }
        ],
        environment: 'sandbox',
        platform: 'apple'
      }
      verifyPayment = sinon.spy()
      ValidatorGoogle_verify = sinon.spy()

    it 'ios', ->
      o.payment_validate {platform: 'ios', transaction: {type: 'ios-appstore', subscription: true, appStoreReceipt: 'rece'}}, spy
      assert.equal 1, verifyPayment.callCount
      assert.equal 'apple', verifyPayment.getCall(0).args[0]
      assert.deepEqual {receipt: 'rece', secret: 'shs'}, verifyPayment.getCall(0).args[1]
      verifyPayment.getCall(0).args[2](null, success_ios)
      assert.equal 1, spy.callCount
      assert.deepEqual {expire: null, product_id: '50monetas2', transaction_id: '1000000633801337', transaction_date: new Date(1583184628000)}, spy.getCall(0).args[0]

    it 'ios (subscription)', ->
      clock.tick 1583418041000
      o.payment_validate {platform: 'ios', transaction: {type: 'ios-appstore', subscription: true, appStoreReceipt: 'rece'}}, spy
      verifyPayment.getCall(0).args[2](null, subscription_ios)
      assert.deepEqual {expire: 4000,  product_id: 'vip5', transaction_id: '1000000635313423', transaction_date: new Date(1583417745000)}, spy.getCall(0).args[0]

    it 'ios (error)', ->
      o.payment_validate {platform: 'ios', transaction: {type: 'ios-appstore', appStoreReceipt: 'rece'}}, spy
      verifyPayment.getCall(0).args[2]('err', {})
      assert.equal 0, spy.callCount

    it 'ios (error platform)', ->
      o.payment_validate {platform: 'android', transaction: {type: 'ios-appstore', appStoreReceipt: 'rece'}}, spy
      assert.equal 0, verifyPayment.callCount

    it 'google', ->
      o.payment_validate {platform: 'android', product_id: 'prd', subscription: false, transaction: {type: 'android-playstore', purchaseToken: 'pto'}}, spy
      assert.equal 1, ValidatorGoogle_verify.callCount
      assert.deepEqual {productId: 'prd', purchaseToken: 'pto', subscription: false}, ValidatorGoogle_verify.getCall(0).args[0]
      ValidatorGoogle_verify.getCall(0).args[1](null, success_android)
      assert.equal 1, spy.callCount
      assert.deepEqual {expire: null, product_id: 'prd', transaction_id: 'GPA.3396-4053-7567-83173', transaction_date: new Date(1583373013055)}, spy.getCall(0).args[0]

    it 'google (subscription)', ->
      clock.tick 1583374211715
      o.payment_validate {platform: 'android', product_id: 'sub', subscription: true, transaction: {type: 'android-playstore', purchaseToken: 'pto'}}, spy
      ValidatorGoogle_verify.getCall(0).args[1](null, subscription_android)
      assert.deepEqual {expire: 4000,  product_id: 'sub', transaction_id: 'GPA.3398-1855-5167-65974..0'}, spy.getCall(0).args[0]

    it 'google (err)', ->
      o.payment_validate {platform: 'android', product_id: 'prd', transaction: {type: 'android-playstore', purchaseToken: 'pto'}}, spy
      ValidatorGoogle_verify.getCall(0).args[1]('err', success_android)
      assert.equal 0, spy.callCount

    it 'google (err platform)', ->
      o.payment_validate {platform: 'ios', product_id: 'prd', transaction: {type: 'android-playstore', purchaseToken: 'pto'}}, spy
      assert.equal 0, ValidatorGoogle_verify.callCount
