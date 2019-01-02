google = require('google-auth-library')


module.exports.ApiGoogle = class ApiGoogle
  constructor: (config)->
    @_g = new google.OAuth2Client(config.google.id, config.google.key, config.server + '/g')
    @_g.generateAuthUrl({scope: 'https://www.googleapis.com/auth/plus.me', access_type: 'offline'})
    if config.code_url
      @_gcode_url = new google.OAuth2Client(config.google.id, config.google.key, config.server + config.code_url)
      @_gcode_url.generateAuthUrl({scope: 'https://www.googleapis.com/auth/plus.me', access_type: 'offline'})

  authorize: ({code, params}, callback)->
    api = if @_gcode_url and params and params.code_url then @_gcode_url else @_g
    api.getToken code, (err, data)=>
      if err
        return callback(null)
      api.verifyIdToken {idToken: data.id_token}, (err, data)=>
        if err
          return callback(null)
        callback({uid: data.payload.sub, language: data.payload.locale, name: data.payload.name, img: data.payload.picture})
