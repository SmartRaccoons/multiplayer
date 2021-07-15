qs = require('querystring')
crypto = require('crypto')


module.exports.ApiOdnoklassniki = class ApiOdnoklassniki

  constructor: (@config)->
    # console.info @config

  authorize: (url_params)->
    try
      url = qs.parse(url_params)
    catch e
      return null
    try
      params_hash = do =>
        crypto.createHash('md5').update(url.logged_user_id + url.session_key + @config.odnoklassniki.app_key_secret).digest("hex")
    catch e
      return null
    if !url.logged_user_id or !url.auth_sig or params_hash isnt url.auth_sig
      return null
    params = {uid: url.logged_user_id}
    try
      params.name = url.user_name
      params.img = url.user_image
    catch e
    console.info params
    return params
