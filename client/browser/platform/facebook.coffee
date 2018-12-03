window.o.PlatformFacebook = class Facebook extends window.o.PlatformCommon
  _scope: ''
  constructor: (@options)->
    super()
    @router = new window.o.Router()
    @router.$el.appendTo('body')
    fn = (event, data)=>
      if event is 'authenticate:error'
        @auth_error()
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', =>
      window.FB.getLoginStatus ((response)=> @_auth_callback(response, @auth)), {scope: @_scope}
    @

  init: (callback)->
    $('<script>').attr
      'src': '//connect.facebook.net/en_US/sdk.js'
      'id': 'facebook-jssdk'
    .appendTo document.body

    window.fbAsyncInit = ->
      window.FB.init
        appId      : App.config.facebook_id
        xfbml      : true
        version    : 'v2.5'
      callback()

  buy: ({service, id})=>
    window.FB.ui
      method: 'pay'
      action: 'purchaseitem'
      product: "https://#{App.config.server}/d/og/#{service}#{App.lang}.html"
      request_id: id
    , ->

  share: (params = {}, callback=->)->
    window.FB.ui
      method: 'share'
      href: params.href
    , (response)=>
      if response and response.error_code
        return callback(response.error_code)
      callback()

  _auth_callback: (response, callback=@auth_error)->
    if response.status is 'connected'
      return @auth_send({access_token: response.authResponse.accessToken})
    return callback()

  auth: -> window.FB.login ((response)=> @_auth_callback(response)), {scope: @_scope}

  auth_error: ->
    @router.message(_l('standalone login error')).bind 'login', => @auth()
