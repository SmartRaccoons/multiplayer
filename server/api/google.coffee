google = require('google-auth-library')


module.exports.ApiGoogle = class ApiGoogle
  constructor: (config)->
    @g = new google.OAuth2Client(config.google.id, config.google.key, config.server + '/g')
    @g.generateAuthUrl({scope: 'https://www.googleapis.com/auth/plus.me', access_type: 'offline'})

  authorize: (code, callback)->
    @g.getToken code, (err, data)=>
      if err
        return callback(null)
      @g.verifyIdToken {idToken: data.id_token}, (err, data)=>
        if err
          return callback(null)
        callback({uid: data.payload.sub, language: data.payload.locale, name: data.payload.name, img: data.payload.picture})
