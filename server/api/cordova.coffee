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
          return console.info 'apple error', err
        callback
          product_id: success.productId
          transaction_id: success.transactionId
          transaction_date: new Date(parseInt(success.purchaseDate))
          expire: if success.expirationDate? then parseInt(success.expirationDate) - new Date().getTime() else null

    if params.platform is 'android' and params.transaction.type is 'android-playstore'
      return @_android_validate.verify {
        productId: params.product_id
        subscription: params.subscription
        purchaseToken: params.transaction.purchaseToken
      }, (err, success)=>
        if err
          return console.info err
        callback Object.assign {
          product_id: params.product_id
          transaction_id: success.orderId
          expire: if params.subscription then parseInt(success.expiryTimeMillis) - new Date().getTime() else null
        }, if !params.subscription then {
          transaction_date: new Date(parseInt(success.purchaseTimeMillis))
        }
