apple_signin = require('apple-signin-auth')


module.exports.ApiApple = class ApiApple
  constructor: (@config)->

  authorize: ({code, params}, callback)->
    apple_signin.getAuthorizationToken(code, {
      clientID: @config.apple.client_id
      redirectUri: @config.server + @config.apple.login_post
      clientSecret: apple_signin.getClientSecret({
        clientID: @config.apple.client_id
        teamID: @config.apple.team_id
        privateKey: @config.apple.key_p8
        keyIdentifier: @config.apple.key_id
      })
    }).then (authorize)->
      if !(authorize and authorize.id_token)
        return callback(null)
      apple_signin.verifyIdToken(authorize.id_token).then (user)->
        if !(user and user.sub)
          return callback(null)
        callback
          uid: user.sub
          name: if !(params and params.user) then '' else do =>
            try
              decode = JSON.parse(params.user)
              return [decode.name.firstName, decode.name.lastName].join ' '
            catch e
              return ''
      .catch ->
        callback(null)
    .catch ->
      callback(null)
