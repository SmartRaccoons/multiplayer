window.o.PlatformStandalone = class Standalone extends window.o.PlatformCommon
  Authorize: window.o.ViewPopupAuthorize
  _authorize:
    draugiem: 'dr_auth_code'
    facebook: 'access_token'
    google: 'code'
    apple: 'apple'

  constructor: ->
    super ...arguments
    fn = (event, data)=>
      if event is 'authenticate:error'
        @router
        .message
          body: _l('Authorize.standalone login error')
          actions: [
            {'reload': _l('Authorize.button.reload')}
            {'login': _l('Authorize.button.login')}
          ]
          close: !!@options.anonymous
        .bind 'login', =>
          @auth_popup()
        .bind 'close', =>
          @router.trigger 'anonymous'
      if event is 'authenticate:params'
        @_auth_clear()
        for platform, value of data
          Cookies.set(platform, value)
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', => @_auto_login()
    @router.bind 'logout', =>
      @_auth_clear()
      window.location.reload true

  auth_popup: ->
    authorize = @router.subview_append new @Authorize({close: !!@options.anonymous, platforms: Object.keys(App.config.login), parent: @router.$el})
    authorize.bind 'authorize', (platform)=>
      if platform is 'email'
        return @auth_email()
      window.location.href = App.config.login[platform] + '?language=' + App.lang
    .bind 'close', =>
      @router.trigger 'anonymous'
    .render()

  _auth_clear: -> Object.keys(App.config.login).forEach (c)-> Cookies.set(c, '')

  auth: ->
    params = {}
    for platform in Object.keys(App.config.login)
      argument = @_authorize[platform]
      if @router._get(argument)
        params[platform] = @router._get(argument)
        @_auth_clear()
        Cookies.set(platform, params[platform])
        window.history.replaceState({}, document.title, window.location.pathname)
        @auth_send params
        return true
    params = {}
    for platform in Object.keys(App.config.login)
      if Cookies.get(platform)
        params[platform] = Cookies.get(platform)
        @auth_send params
        return true
    return false
