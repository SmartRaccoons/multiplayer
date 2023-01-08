window.o.PlatformCordovaNotification = class CordovaNotification extends window.SimpleEvent
  constructor: ->
    super ...arguments
    if !@available()
      return
    FirebasePlugin.setBadgeNumber(0)
    FirebasePlugin.onMessageReceived (message)=>
      if 'notification' is message.messageType
        if message.tap
          @trigger 'tap', message

  available: -> !!window.FirebasePlugin

  grant: (callback)->
    FirebasePlugin.grantPermission callback

  has: (callback)->
    FirebasePlugin.hasPermission callback

  token: ->
    @_firebase_token = null
    firebase_token_save = (token)=>
      if !token or token is @_firebase_token
        return
      @_firebase_token = token
      @trigger "token", {token: @_firebase_token}
    window.FirebasePlugin.getToken firebase_token_save
    window.FirebasePlugin.onTokenRefresh firebase_token_save

  android_notification_channel: (channel)->
    FirebasePlugin.createChannel Object.assign({
      id: "channel_id"
      name: "Default"
      description: ""
      sound: "default"
      vibration: true
      light: true
      lightColor: -1
      importance: 4
      badge: true
      visibility: 1
    }, channel, {
      lightColor: if channel.lightColor then parseInt(channel.lightColor, 16).toString() else -1
    })
