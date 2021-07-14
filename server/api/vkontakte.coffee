qs = require('querystring')
crypto = require('crypto')


module.exports.ApiVkontakte = class ApiVkontakte

  constructor: (@config)->
    # console.info @config

  authorize: (url_params)->
    try
      url = qs.parse(url_params)
    catch e
      return null
    try
      params_hash = do =>
        ordered = qs.stringify url.sign_keys.split(',').reduce (acc, key)->
          Object.assign acc, {[key]: url[key]}
        , {}
        return crypto
        .createHmac('sha256', @config.vkontakte.app_secret)
        .update ordered
        .digest()
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=$/, '')
    catch e
      return null
    if !url.sign or params_hash isnt url.sign
      return null
    params = {uid: url.viewer_id}
    try
      api_result = JSON.parse(url.api_result)
      params.name = [api_result.response[0].first_name, api_result.response[0].last_name].join ' '
      params.img = api_result.response[0].photo
    catch e
      return null
    return params
