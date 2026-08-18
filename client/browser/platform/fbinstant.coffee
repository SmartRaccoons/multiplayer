window.o.PlatformFbinstant = class Fbinstant extends window.o.PlatformCommon
  _name: 'fbinstant'
  constructor: (@options)->
    super ...arguments
    fn = (event, data)=>
      if event is 'authenticate:error'
        @auth_error()
      if event is 'authenticate:success'
        @router.unbind 'request', fn
        if @options.payments
          FBInstant.payments.onReady =>
            @_get_catalog()
            @_get_payments()
    @router.bind 'request', fn
    @router.bind 'connect', =>
      @auth_send { 'facebook': 'fbinstant:' + @_fbinstant_signature, language: FBInstant.getLocale() }
    @router.bind "request:buy:#{@_name}", ({service, transaction_id})=>
      productID = @options.payments and @options.payments[service]
      if !productID
        return
      FBInstant.payments.purchaseAsync({productID, developerPayload: "#{transaction_id}"})
      .then (purchase)=>
        @_payment_validate(purchase)
      .catch (err)->
        console.error 'FBInstant.payments.purchaseAsync error', err
    @router.bind "request:buy:#{@_name}:validate", ({id_local})=>
      FBInstant.payments.consumePurchaseAsync(id_local)
    @

  _get_catalog: ->
    return unless @options.payments_ready
    FBInstant.payments.getCatalogAsync().then (products)=>
      # per-service, not an inverted productID->service map: multiple services (e.g. vip/vipyear
      # tiers) can share the same product ID, which a simple inversion would silently collapse
      services = Object.keys(@options.payments).map (service)=>
        productID = @options.payments[service]
        product = products.find (p)-> p.productID is productID
        return unless product
        {service, price_str: product.price}
      @options.payments_ready services.filter (v)-> v

  _get_payments: ->
    FBInstant.payments.getPurchasesAsync().then (purchases)=>
      purchases.forEach (purchase)=> @_payment_validate(purchase)

  _payment_validate: (purchase)->
    @_queue_success =>
      @router.send "buy:#{@_name}:validate", {signature: purchase.signedRequest, id_local: purchase.purchaseToken}

  # notification_enable: (callback)->
  #   FBInstant.player.canSubscribeBotAsync().then (can_subscribe)=>
  #     callback can_subscribe
  #   .catch =>
  #     callback false

  # notification_ask: (callback)->
  #   FBInstant.player.subscribeBotAsync().then =>
  #     callback true
  #   .catch =>
  #     callback false

  init: (assets, callback)->
    loaded = 0
    start = =>
      if loaded < assets.length
        FBInstant.setLoadingProgress(loaded * 100 / assets.length)
        return
      FBInstant.startGameAsync().then =>
        FBInstant.player.getSignedPlayerInfoAsync()
        .then (result)=>
          @_fbinstant_signature = result.getSignature()
          callback()

    $('<script>').attr
      'src': 'https://connect.facebook.net/en_US/fbinstant.8.0.js'
      'id': 'facebook-jssdk'
    .on 'load', =>
      FBInstant.initializeAsync().then =>
        if assets.length is 0
          return start()
        assets.forEach (src)->
          i = new Image()
          i.onload = ->
            loaded++
            start()
          i.src = src
          start()
    .appendTo document.body

  # invite: (params = {}, callback=->)->
  #   FBInstant.shareAsync Object.assign( {intent: 'INVITE', image: '', text: ''}, params )
  #   .then =>
  #     callback()

  # share: (params = {}, callback=->)->
  #   FBInstant.shareAsync Object.assign( {intent: 'SHARE', image: '', text: ''}, params )
  #   .then =>
  #     callback()

  auth_error: ->
    @router
    .message
      body: _l('Authorize.integrated login error')
      actions: [
        {'reload': _l('Authorize.button.reload')}
      ]
