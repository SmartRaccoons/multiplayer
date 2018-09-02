window.o.Router = class Router extends window.o.View
  className: 'container'
  template: """
  """

  _get: (param)->
    for v in ['search', 'hash']
      result =  window.location[v].match(
        new RegExp("(\\?|&|#)" + param + "(\\[\\])?=([^&]*)")
      )
      if result
        return result[3]
    return false

  constructor: ->
    super ...arguments
    App.events.trigger 'router:init', @
    @_active = null

  connect: ->
    @_unload()
    @render()
    @trigger 'connect'

  disconnect: -> @message(_l('Disconnect'))

  login_duplicate: -> @message(_l('Login duplicate'))

  connect_failed: -> @message(_l('connect failed'))

  request: (event, data)->
    @trigger 'request', event, data
    @trigger "request:#{event}", data

  # send: ->
  message_remove: ->
    if @_message
      @_message.remove()
      @_message = null

  message: (params)->
    @message_remove()
    if typeof params is 'string'
      params = {body: params}
    @_message = new window.o.ViewPopup(_.extend({parent: @$el, close: false}, params)).render()
    @_message.bind 'reload', -> window.location.reload true
    @_message

  _active_check: (name)-> (@_active and @_active._name is name)

  _unload: ->
    if @_active
      @_active.remove()
      @_active = null

  _load: (view, options)->
    @_unload()
    @_active = new window.o['View' + view.charAt(0).toUpperCase() + view.slice(1)](options)
    @$el.prepend @_active.$el
    @_active.render()
    @_active._name = view
    @_active
