window.o.ViewPopup = class Popup extends window.o.View
  _remove_timeout: 200
  className: 'popup'
  template: """
    <div>
       <% if (!('close' in self.options) || self.options.close){ %>
        <button data-action='close' class='popup-close'>×</button>
       <% } %>

       <% if (self.options.head) { %>
        <h1><%= typeof self.options.head === 'function' ? self.options.head({'self': self}) : self.options.head %></h1>
       <% } %>

       <div>
         <%= typeof self.options.body === 'function' ? self.options.body({'self': self}) : self.options.body %>
       </div>
    </div>
  """
  events:
    'click button[data-action="close"]': -> @remove()
    'click [data-click]': (e)->
      el = $(e.target)
      @trigger el.attr('data-click'), el.attr('data-click-attr')
      if !el.is('[data-stay]')
        @remove()

  constructor: ->
    super ...arguments
    if @options.parent
      @$el.appendTo @options.parent
    @

  remove: ->
    if !@_remove_timeout
      return super ...arguments
    @$el.addClass('popup-before-remove')
    setTimeout =>
      super ...arguments
    , @_remove_timeout


  render: ->
    super ...arguments
    @$container = $(@$('div')[0])
    @$el.addClass('popup-before-render')
    @$el.height()
    @$el.removeClass('popup-before-render')
    @
