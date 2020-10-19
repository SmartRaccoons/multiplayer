request = require('google-oauth-jwt').requestWithJWT()
util = require('util')


module.exports = class Verifier
  constructor: (@options)->

  verify: (receipt, cb) ->
    urlPattern = 'https://www.googleapis.com/androidpublisher/v3/applications/%s/purchases/%s/%s/tokens/%s'
    finalUrl = util.format(urlPattern, encodeURIComponent(@options.packageName), encodeURIComponent(if receipt.subscription then 'subscriptions' else 'products'), encodeURIComponent(receipt.productId), encodeURIComponent(receipt.purchaseToken))
    request {
      url: finalUrl
      jwt:
        email: @options.email
        key: @options.key
        keyFile: undefined
        scopes: [ 'https://www.googleapis.com/auth/androidpublisher' ]
    }, (err, res, body) ->
      if err
        return cb(err)
      obj = JSON.parse(body)
      if 'error' of obj
        cb new Error( obj.error.message + ' ' + JSON.stringify(receipt) )
      else if ( 'purchaseTimeMillis' of obj ) or ( 'expiryTimeMillis' of obj )
        cb null, obj
      else
        cb new Error('body did not contain expected json object')
