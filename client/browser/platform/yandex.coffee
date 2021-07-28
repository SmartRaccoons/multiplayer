window.o.PlatformYandex = class Yandex extends window.o.PlatformCommon
  _name: 'yandex'

  constructor: ->
    super ...arguments
    fn = (event, data)=>
      if event is 'authenticate:error'
        @auth_error()
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', =>
    # @router.bind "request:buy:#{@_name}", ({service, transaction_id, price})=>
    #   FAPI.UI.showPayment(
    #     params.name,
    #     params.description,
    #     params.code,
    #     price,
    #     null,
    #     JSON.stringify({transaction_id}),
    #     'ok',
    #     true
    #   )
    @

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

  auth_error: ->
    @router
    .message
      close: true
      body: _l('Authorize.integrated login error')
    .bind 'close', => @router.trigger 'anonymous'
