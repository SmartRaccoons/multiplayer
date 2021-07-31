window.o.PlatformYandex = class Yandex extends window.o.PlatformCommon
  _name: 'yandex'

  constructor: ->
    super ...arguments
    fn = (event, data)=>
      if event is 'authenticate:error'
        @auth_error()
      if event is 'authenticate:success'
        @router.unbind 'request', fn
        if @options.payments
          @__init_payments()
    @router.bind 'request', fn
    @router.bind 'connect', =>
    @router.bind "request:buy:#{@_name}", ({service, transaction_id})=>
      @_payments.purchase({ id: @options.payments[service], developerPayload: "#{transaction_id }" }).then (purchase)=>
        @_payment_validate(purchase)
      .catch (err)->
    @router.bind "request:buy:#{@_name}:validate", ({id_local})=>
      @_payments.consumePurchase(id_local)
    @

  _payment_validate: (purchase)->
    @router.send "buy:#{@_name}:validate", {signature: purchase.signature, id_local: purchase.purchaseToken}

  _get_user: (callback = ->, callback_error = ->)->
    ysdk.getPlayer({signed: true, scope: true})
    .then (player)=>
      @auth_send({yandex: player.signature})
      callback()
    .catch =>
      callback_error()

  auth: ->
    @_get_user ->, =>
      ysdk.auth.openAuthDialog()
      .then => @auth()
      .catch =>

  __init: (callback)->
    script = document.createElement('script')
    script.async = true
    script.onload = =>
      YaGames
      .init()
      .then (ysdk)=>
        window.ysdk = ysdk
        callback()
        @_get_user ->, =>
          @router.trigger 'anonymous'

    script.src = 'https://yandex.ru/games/sdk/v2'
    document.head.appendChild(script)

  __init_payments: ->
    ysdk.getPayments({ signed: true }).then (payments) =>
      @_payments = payments
      @_get_catalog()
      @_get_payments()
      # @trigger 'payments'
    .catch (err)->

  _get_catalog: ->
    _invert = {}
    for service, id of @options.payments
      _invert[id] = service
    @_payments.getCatalog().then (products)=>
      @options.payments_ready products.map (product)=>
        {service: _invert[product.id], price_str: product.price, price: parseInt(product.priceValue), currency: product.priceCurrencyCode}
#       {
#     "id": "chips1",
#     "title": "1 000 фишек",
#     "description": "Фишки для игры",
#     "imageURI": "https://avatars.mds.yandex.net/get-games/1881371/2a0000017aed1e7a0014ec7a3591c5869959//default256x256",
#     "price": "100 ₽",
#     "priceValue": "100",
#     "priceCurrencyCode": "RUR"
# }

  _get_payments: ->
    @_payments.getPurchases().then (purchases)=>
      if purchases.length > 0
        @_payment_validate Object.assign {signature: purchases.signature}, purchases[0]

  auth_error: ->
    @router
    .message
      close: true
      body: _l('Authorize.integrated login error')
    .bind 'close', => @router.trigger 'anonymous'
