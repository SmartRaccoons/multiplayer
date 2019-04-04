window.o.PlatformCommon = class Common

  language_check: (callback)->
    if !window._locales_default
      return callback()
    @router.subview_append(new window.o.ViewPopupLanguage())
    .bind 'language', (language)=>
      App.lang = language
    .bind 'remove', => callback()
    .render()
    .$el.appendTo(@router.$el)

  connect: (params)->
    window.o.Connector Object.assign({
      router: @router
      address: App.config.server
      version: App.version
      version_callback: => @router.message(_l('Authorize.version error'))
    }, params)

  buy: (service)-> @router.send "coins:buy:#{@_name}", service

  auth_send: (p)->
    @router.message(_l('Authorize.Authorizing'))
    @router.send 'authenticate:try', p
