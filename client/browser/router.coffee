window.o.Router = class Router extends window.o.View
  className: 'container'
  template: """
  """

  _get: (param, string = '')->
    for v in (if string then [string] else ['search', 'hash'].map( (v)-> window.location[v] ) )
      result =  v.match(
        new RegExp("(\\?|&|#)" + param + "(\\[\\])?=([^&]*)")
      )
      if result
        return decodeURIComponent(result[3])
    return false

  constructor: ->
    super ...arguments
    App.events.trigger 'router:init', @
    @_active = null

  connect: ->
    @_unload()
    @render()
    @trigger 'connect'

  connecting: -> @message(_l('Authorize.Connecting'))

  disconnect: ->
    @message
      body:_l('Authorize.Disconnect')
      actions: [ {'reload': _l('Authorize.button.reload')} ]

  login_duplicate: ->
    @message
      body: _l('Authorize.Login duplicate')
      actions: [ {'reload': _l('Authorize.button.reload')} ]

  connect_failed: ->
    @message
      body: _l('Authorize.connect failed')
      actions: [ {'reload': _l('Authorize.button.reload')} ]

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
    @_load_append(@_active.$el)
    @_active.render()
    @_active._name = view
    @_active

  _load_append: (el)-> el.appendTo @$el
