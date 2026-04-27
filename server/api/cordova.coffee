fs = require('fs')
iap = require('iap')
ValidatorAndroid = require('./cordova.google')
{ AppStoreServerAPIClient, Environment, SignedDataVerifier } = require "@apple/app-store-server-library"


module.exports = class Cordova
  constructor: ({android, ios})->
    @options = {ios}
    @_android_validate = new ValidatorAndroid(android)
    @_ios_validate = do ->
      client = new AppStoreServerAPIClient(
        ios.privateKey
        ios.keyId
        ios.issuerId
        ios.bundleId
        Environment.PRODUCTION
      )
      verifierInit = (production)->
        new SignedDataVerifier(
          [
            fs.readFileSync __dirname + '/AppleRootCA-G3.cer'
            fs.readFileSync __dirname + '/AppleRootCA-G2.cer'
            fs.readFileSync __dirname + '/AppleIncRootCertificate.cer'
          ]
          true
          if production then Environment.PRODUCTION else Environment.SANDBOX
          ios.bundleId
          Number ios.id
        )

      verifier = verifierInit true
      verifierSandbox = verifierInit false
      (jwsRepresentation)->
        try
          decoded = await verifier.verifyAndDecodeTransaction jwsRepresentation
        catch prodError
          decoded = await verifierSandbox.verifyAndDecodeTransaction jwsRepresentation
          decoded.sandbox = true
          return decoded
        throw new Error 'Wrong bundleId' if ios.bundleId isnt decoded.bundleId
        throw new Error 'Missing productId' unless decoded.productId?
        throw new Error 'Missing transactionId' unless decoded.transactionId?
        appleResponse = await client.getTransactionInfo decoded.transactionId
        appleDecoded = await verifier.verifyAndDecodeTransaction appleResponse.signedTransactionInfo
        appleDecoded

  payment_validate: (params, callback)->
    if params.platform is 'ios' and params.transaction.type is 'apple-sk2'
      try
        success = await @_ios_validate params.transaction.jwsRepresentation
        callback null,
          product_id: success.productId
          transaction_id: "#{success.transactionId}#{if success.sandbox then '-sandbox' else ''}"
          transaction_date: new Date(parseInt(success.purchaseDate))
          expire: if success.expirationDate? then parseInt(success.expirationDate) - new Date().getTime() else null
      catch err
        return callback err
    if params.platform is 'ios' and params.transaction.type is 'ios-appstore'
      return iap.verifyPayment 'apple', {secret: @options.ios.shared_secret, receipt: params.transaction.appStoreReceipt}, (err, success)=>
        if err
          return callback err
        callback null,
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
          return callback err
        callback null, Object.assign {
          product_id: params.product_id
          transaction_id: success.orderId
          expire: if params.subscription then parseInt(success.expiryTimeMillis) - new Date().getTime() else null
        }, if !params.subscription then {
          transaction_date: new Date(parseInt(success.purchaseTimeMillis))
        }
