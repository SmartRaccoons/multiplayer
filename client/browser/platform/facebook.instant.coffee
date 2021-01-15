window.o.PlatformFacebookInstant = class FacebookInstant extends window.o.PlatformCommon
  _name: 'facebook'
  constructor: (@options)->
    super ...arguments
    fn = (event, data)=>
      if event is 'authenticate:error'
        @auth_error()
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', =>
      FBInstant.player.getSignedPlayerInfoAsync( [ FBInstant.getLocale(), FBInstant.player.getName(), FBInstant.player.getPhoto() or '' ].join(';') )
      .then (result)=>
        @auth_send { 'facebook': 'fbinstant:' + result.getSignature()}
    # @router.bind "request:buy:#{@_name}", ({service, id})=>
      # subscription = App.config.buy.subscription and service in Object.keys(App.config.buy.subscription)
      # window.FB.ui {
      #   method: 'pay'
      #   action: if subscription then 'create_subscription' else 'purchaseitem'
      #   product: "#{App.config.server}/d/og/service-#{service}-#{App.lang}.html"
      #   request_id: id
      # }, ->
        # {subscription_id: 348322315297870, status: "active"}
    @

  # subscription_action: ({action, subscription_id})->
    # action: 'reactivate_subscription', 'cancel_subscription', 'modify_subscription'
    # window.FB.ui {
    #   method: 'pay'
    #   action
    #   subscription_id
    # }, ->

  init: (assets, callback)->
    loaded = 0
    start = =>
      if loaded < assets.length
        FBInstant.setLoadingProgress(loaded * 100 / assets.length)
        return
      FBInstant.startGameAsync().then => callback()

    FBInstant.initializeAsync().then =>
      assets.forEach (src)->
        i = new Image()
        i.onload = ->
          loaded++
          start()
        i.src = src
        start()

  invite: (params = {}, callback=->)->
    FBInstant.shareAsync Object.assign( {intent: 'INVITE', image: '', text: ''}, params )
    .then =>
      callback()

  share: (params = {}, callback=->)->
    FBInstant.shareAsync Object.assign( {intent: 'SHARE', image: '', text: ''}, params )
    .then =>
      callback()

  auth_error: ->
    @router
    .message
      body: _l('Authorize.integrated login error')
      actions: [
        {'reload': _l('Authorize.button.reload')}
      ]
