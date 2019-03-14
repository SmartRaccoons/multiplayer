window.o.PlatformInbox = class Inbox extends window.o.PlatformCommon
  constructor: ->
    super()
    @router = new window.o.Router()
    @router.$el.appendTo('body')
    fn = (event, data)=>
      if event is 'authenticate:error'
        @router.message(_l('Authorize.integrated login error'))
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn
    @router.bind 'connect', => @auth_send({ inbox: @router._get('uid'), language: @router._get('language') })
    @router.bind 'request:buy:inbox:response', ({link})=>
      @router.subview_append new window.o.ViewPopupIframe({link, parent: @router.$el}).render()
    @
