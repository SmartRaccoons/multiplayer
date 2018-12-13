window.o.PlatformCommon = class Common

  language_check: (callback)->
    if !window._locales_default
      return callback()
    @router.subview_append(new window.o.ViewPopupLanguage())
    .bind 'language', (language)=>
      App.lang = language
      @router.render()
    .bind 'remove', => callback()
    .render()
    .$el.appendTo(@router.$el)

  connect: (params)->
    window.o.Connector Object.assign({
      router: @router
      address: App.config.server
      version: document.body.getAttribute('data-version')
      version_callback: => @router.message(_l('version error'))
    }, params)

  auth_send: (p)->
    @router.message(_l('Authorizing'))
    @router.send 'authenticate:try', p
