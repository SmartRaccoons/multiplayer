window.o.PlatformVkontakte = class Vkontakte extends window.o.PlatformCommon
  _name: 'vkontakte'

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
        vkontakte: window.location.href.split('?')[1]
        language: if @router._get('language') is '3' then 'en' else 'ru'
    @

  __init: (callback)->
    script = document.createElement('script')
    script.onload = ->
      vkBridge.send('VKWebAppInit')
      callback()
    script.src = '//unpkg.com/@vkontakte/vk-bridge/dist/browser.min.js'
    document.head.appendChild(script)

  invite: ->
    vkBridge.send("VKWebAppShowInviteBox", {})

  share: ({link})->
    vkBridge.send("VKWebAppShare", {link})
