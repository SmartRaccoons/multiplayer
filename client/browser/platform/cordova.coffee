class PopupCode extends window.o.ViewPopup
  className: window.o.ViewPopupAuthorize::className


window.o.PlatformCordova = class Cordova extends window.o.PlatformCommon
  _authorize:
    draugiem: 'dr_auth_code'
    facebook: 'access_token'
    google: 'code'

  constructor: (@options)->
    super()
    @_login_code_params = {}
    @router = new window.o.Router()
    @router.$el.appendTo('body')
    fn = (event, data)=>
      if event is 'authenticate:error'
        @_login_code_params.random = null
        @router.message(_l('standalone login error')).bind 'login', =>
          @auth_popup()
      if event is 'authenticate:success'
        @router.unbind 'request', fn
      if event is 'authenticate:code'
        @_login_code_params.random = data.random
        @auth_popup_device @_login_code_params
      if event is 'authenticate:params'
        for platform, value of data
          Cookies.set(platform, value)
    @router.bind 'request', fn
    @router.bind 'connect', =>
      @_login_code_params.random = null
      if !@auth()
        if !@options.language_check
          return @auth_popup()
        @language_check => @auth_popup()
    @router.bind 'logout', =>
      @_auth_clear()
      window.location.reload true

  connect: ->
    super({mobile: true})

  auth_popup_device: ({random, platform})->
    link = [App.config.server, App.config.login[platform], '/', random].join('')
    link_text = link.replace('https://', '').replace('http://', '')
    @router.subview_append(new PopupCode({
      head: _l('Authorize') + ' ' + platform
      body: _l('Authorize link', { link, link_text })
    }))
    .bind 'remove', => @auth_popup()
    .render().$el.appendTo @router.$el

  auth_popup: ->
    authorize = @router.subview_append new window.o.ViewPopupAuthorize({platforms: Object.keys(App.config.login)})
    authorize.bind 'authorize', (platform)=>
      @_login_code_params.platform = platform
      if !@_login_code_params.random
        return @router.send 'authenticate:code', {language: App.lang}
      @auth_popup_device @_login_code_params
    authorize.render().$el.appendTo @router.$el

  _auth_clear: -> Object.keys(App.config.login).forEach (c)-> Cookies.set(c, '')

  auth: ->
    params = {}
    for platform in Object.keys(App.config.login)
      if Cookies.get(platform)
        params[platform] = Cookies.get(platform)
        @auth_send params
        return true
    return false
