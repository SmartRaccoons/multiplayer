firebase_admin = require('firebase-admin')


exports.CordovaNotify = class Notify
  init: (options)->
    firebase_admin.initializeApp({
      credential: firebase_admin.credential.cert(options.serviceAccount)
      databaseURL: options.databaseURL
    })

  notification: (firebaseToken, notification={title: '', body: ''}, options=null)->
    payload =
      notification: Object.assign {sound: 'default', badge: '0'}, notification
    options = Object.assign {priority: 'normal', timeoToLive: 60 * 60}, options
    firebase_admin.messaging().sendToDevice(firebaseToken, payload, options)
