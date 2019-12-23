firebase_admin = require('firebase-admin')


exports.CordovaNotify = class Notify
  init: (options)->
    firebase_admin.initializeApp({
      credential: firebase_admin.credential.cert(options.credential)
      databaseURL: options.databaseURL
    })

  notification: ({token, title, body, timeout, sound}, callback = ->)->
    firebase_admin.messaging().send({
      token
      notification:
        title: title
        body: body
      android:
        priority: 'HIGH'
        ttl: timeout
        notification:
          channel_id: sound
          sound: sound
          notification_priority: 'PRIORITY_HIGH'
      apns:
        payload:
          aps:
            badge: 1
            sound: "#{sound}.caf"
    }, false).then (response)=>
      if response.results and response.results[0].error
        return callback(response.results[0].error, response)
      return callback(null, response)
    .catch (error)=> callback(error)
