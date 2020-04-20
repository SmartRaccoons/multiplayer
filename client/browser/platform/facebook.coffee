window.o.PlatformFacebook = class Facebook extends window.o.PlatformCommon
  _name: 'facebook'
  _scope: ''
  constructor: (@options)->
    super ...arguments
    fn = (event, data)=>
      if event is 'authenticate:error'
        @auth_error()
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', =>
      window.FB.getLoginStatus ((response)=> @_auth_callback(response, @auth.bind(@))), {scope: @_scope}
    @router.bind "request:buy:#{@_name}", ({service, id})=>
      subscription = App.config.buy.subscription and service in Object.keys(App.config.buy.subscription)
      window.FB.ui {
        method: 'pay'
        action: if subscription then 'create_subscription' else 'purchaseitem'
        product: "#{App.config.server}/d/og/service-#{service}-#{App.lang}.html"
        request_id: id
      }, ->
        # {subscription_id: 348322315297870, status: "active"}
    @

  subscription_action: ({action, subscription_id})->
    # action: 'reactivate_subscription', 'cancel_subscription', 'modify_subscription'
    window.FB.ui {
      method: 'pay'
      action
      subscription_id
    }, ->

  init: (callback)->
    $('<script>').attr
      'src': '//connect.facebook.net/en_US/sdk.js'
      'id': 'facebook-jssdk'
    .appendTo document.body

    window.fbAsyncInit = =>
      window.FB.init
        appId      : @options.facebook_id
        xfbml      : true
        version    : 'v2.5'
      callback()

  share: (params = {}, callback=->)->
    window.FB.ui
      method: 'share'
      href: params.href
    , (response)=>
      if response and response.error_code
        return callback(response.error_code)
      callback()

  _auth_callback: (response, callback=@auth_error.bind(@))->
    if response.status is 'connected'
      return @auth_send({facebook: response.authResponse.accessToken})
    return callback()

  auth: -> window.FB.login ((response)=> @_auth_callback(response)), {scope: @_scope}

  auth_error: ->
    @router
    .message
      body: _l('Authorize.standalone login error')
      actions: [
        {'reload': _l('Authorize.button.reload')}
        {'login': _l('Authorize.button.login')}
      ]
    .bind 'login', => @auth()
