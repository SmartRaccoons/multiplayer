window.o.PlatformOdnoklassniki = class Odnoklassniki extends window.o.PlatformCommon
  _name: 'odnoklassniki'

  constructor: ->
    super ...arguments
    fn = (event, data)=>
      if event is 'authenticate:error'
        @router.message(_l('Authorize.integrated login error'))
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', =>
      @auth_send
        odnoklassniki: window.location.href.split('?')[1]
        language: 'ru'
    @router.bind "request:buy:#{@_name}", ({service, transaction_id, price})=>
      params = @_buy_params({service, transaction_id, price})
      FAPI.UI.showPayment(
        params.name,
        params.description,
        params.code,
        price,
        null,
        JSON.stringify({transaction_id}),
        'ok',
        true
      )
    @

  __init: (callback)->
    script = document.createElement('script')
    script.defer = 'defer'
    script.onload = ->
      rParams = FAPI.Util.getRequestParameters()
      FAPI.init rParams["api_server"], rParams["apiconnection"], callback, ->
      window.API_callback = (method, result, data)->
    script.src = '//api.ok.ru/js/fapi5.js'
    document.head.appendChild(script)

  invite: ({text, params, selected_uids})->
    FAPI.UI.showInvite(text, params, selected_uids)

  _buy_params: ->
    throw 'buy params missing'
