iap = require('iap')
ValidatorAndroid = require('./cordova.google')


module.exports = class Cordova
  constructor: ({android, ios})->
    @options = {ios}
    @_android_validate = new ValidatorAndroid(android)

  payment_validate: (params, callback)->
    if params.platform is 'ios' and params.transaction.type is 'ios-appstore'
      return iap.verifyPayment 'apple', {secret: @options.ios.shared_secret, receipt: params.transaction.appStoreReceipt}, (err, success)=>
        if err
          return callback err
        # the receipt is per Apple ID, not per purchase: `iap` reports only one "latest" transaction
        # (with subscriptions in the receipt that is a subscription, not the coins just bought),
        # so every transaction of the receipt is listed here for the caller to credit
        purchases = {}
        (success.receipt?.in_app or []).concat(success.latestReceiptInfo or []).forEach (v)->
          if v and v.transaction_id and v.product_id
            purchases[v.transaction_id] = {product_id: v.product_id, transaction_id: v.transaction_id}
        callback null,
          product_id: success.productId
          transaction_id: success.transactionId
          transaction_date: new Date(parseInt(success.purchaseDate))
          expire: if success.expirationDate? then parseInt(success.expirationDate) - new Date().getTime() else null
          purchases: Object.keys(purchases).map (id)-> purchases[id]

    if params.platform is 'android' and params.transaction.type is 'android-playstore'
      return @_android_validate.verify {
        productId: params.product_id
        subscription: params.subscription
        purchaseToken: params.transaction.purchaseToken
      }, (err, success)=>
        if err
          return callback err
        callback null, Object.assign {
          product_id: params.product_id
          transaction_id: success.orderId
          expire: if params.subscription then parseInt(success.expiryTimeMillis) - new Date().getTime() else null
        }, if !params.subscription then {
          transaction_date: new Date(parseInt(success.purchaseTimeMillis))
        }
