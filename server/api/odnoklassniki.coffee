qs = require('querystring')
crypto = require('crypto')
_cloneDeep = require('lodash').cloneDeep


module.exports.ApiOdnoklassniki = class ApiOdnoklassniki

  constructor: (@config)->
    # console.info @config

  _validate_url: (url)->
    url_copy = _cloneDeep(url)
    delete url_copy.sig
    delete url_copy.lang
    delete url_copy.js
    return url.sig is crypto.createHash('md5').update( Object.keys(url_copy).sort().map( (p)-> "#{p}=#{url_copy[p]}" ).join('') + @config.odnoklassniki.app_key_secret ).digest("hex")

  authorize: (url_params)->
    try
      url = qs.parse(url_params)
    catch e
      return null
    if !@_validate_url(url)
      return null
    try
      params_hash = do =>
        crypto.createHash('md5').update(url.logged_user_id + url.session_key + @config.odnoklassniki.app_key_secret).digest("hex")
    catch e
      return null
    if !url.logged_user_id or !url.auth_sig or params_hash isnt url.auth_sig
      return null
    if !url.logged_user_id
      return null
    params = {uid: url.logged_user_id}
    try
      params.name = url.user_name
      params.img = url.user_image
    catch e
    return params

  buy_params: (query, callback)->
    if !@_validate_url(query)
      return callback(null, 'signature', 104)
    try
      extra_attributes = JSON.parse(query.extra_attributes)
    catch e
      return callback(null, 'json error')
    callback {
      transaction_id: extra_attributes.transaction_id
      price: parseInt(query.amount)
    }
