window.o.PlatformStandalone = class Standalone extends window.o.PlatformCommon
  _authorize:
    draugiem: 'dr_auth_code'
    facebook: 'access_token'
    google: 'code'

  constructor: (@options)->
    super()
    @router = new window.o.Router()
    @router.$el.appendTo('body')
    fn = (event, data)=>
      if event is 'authenticate:error'
        @router.message(_l('standalone login error')).bind 'login', =>
          @auth_popup()
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', =>
      if !@auth()
        if !@options.language_check
          return @auth_popup()
        @language_check => @auth_popup()
    @router.bind 'logout', =>
      @_auth_clear()
      window.location.reload true

  auth_popup: ->
    authorize = @router.subview_append new window.o.ViewPopupAuthorize({platforms: Object.keys(App.config.login)})
    authorize.bind 'authorize', (platform)-> window.location.href = App.config.login[platform]
    authorize.render().$el.appendTo @router.$el

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
