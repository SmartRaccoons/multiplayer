qs = require('querystring')
crypto = require('crypto')


module.exports.ApiYandex = class ApiYandex

  constructor: (@config)->
    # console.info @config

  _sign_check: (url_params)->
    try
      [sign, data] = url_params.split('.')
      hmac = crypto.createHmac('sha256', @config.yandex.app_key)
      hmac.update(Buffer.from(data, 'base64').toString('utf8'))
      coded = hmac.digest('base64')
      if sign isnt coded
        return null
      return JSON.parse(Buffer.from(data, 'base64').toString('utf8'))
    catch e
      # console.info e
    return null

  authorize: (url_params, callback)->
    json = @_sign_check(url_params)
    if !json
      return callback null
    if !json.data.uniqueID
      return callback null
    callback {
      uid: json.data.uniqueID
      language: json.data.lang
      img: "https://games-sdk.yandex.ru/api/sdk/v1/player/avatar/#{json.data.avatarIdHash}/islands-retina-small"
      name: json.data.publicName
    }

  payment: (urls_params, callback)->
    json = @_sign_check urls_params
    if !json
      return callback(null)
    data = if Array.isArray(json.data) then json.data[0] else json.data
    if !data.developerPayload
      return callback(null)
    callback {
      token: data.token
      transaction_id: parseInt(data.developerPayload)
    }
