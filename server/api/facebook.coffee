fbgraph = require('fbgraph')
crypto = require('crypto-js')

module.exports.ApiFacebook = class ApiFacebook
  constructor: (options)->
    @options =
      key: options.key

  authorize: (code, callback)->
    if @_instant_validate(code)
      return callback @_instant_get_encoded_data(code)
    return @_authorize_facebook(code, callback)

  _authorize_facebook: (code, callback)->
    fbgraph.setAccessToken(code)
    fbgraph.get '/me?fields=token_for_business,locale,name,picture.width(100)', (err, res)=>
      if err or !res.id
        return callback(null)
      callback
        facebook_uid: res.id
        facebook_token_for_business: res.token_for_business
        name: res.name
        language: res.locale
        img: if res.picture and res.picture.data then res.picture.data.url else null

  _instant_validate: (code)->
    try
      signed_request = code.split('fbinstant:')[1]
      if !signed_request
        return false
      return crypto.enc.Base64.parse( signed_request.split('.')[0].replace(/-/g, '+').replace(/_/g, '/') ).toString() is crypto.HmacSHA256(signed_request.split('.')[1], @options.key).toString()
    catch e
      return false

  _instant_get_encoded_data: (code)->
    try
      encoded_data = JSON.parse( crypto.enc.Base64.parse( code.split('fbinstant:')[1].split('.')[1] ).toString(crypto.enc.Utf8) )
      player_data = encoded_data.request_payload.split(';')
      if !player_data[1] or !encoded_data.player_id
        return null
      return {
        facebook_uid: encoded_data.player_id
        language: player_data[0]
        name: player_data[1].substr(0, 30)
        img: if !player_data[2] then null else player_data[2].substr(0, 300)
      }
    catch e
      return null
