window.o.ViewPopup = class Popup extends window.o.View
  className: 'popup'
  template: """
    <div>
       <% if (!('close' in self.options) || self.options.close){ %>
        <button data-action='close' class='popup-close'>×</button>
       <% } %>
       <% if (self.options.head) { %>
        <h1><%= typeof self.options.head === 'function' ? self.options.head({'self': self}) : self.options.head %></h1>
       <% } %>
       <%= typeof self.options.body === 'function' ? self.options.body({'self': self}) : self.options.body %>
    </div>
  """
  events:
    'click button[data-action="close"]': -> @remove()
    'click [data-click]': (e)->
      @trigger $(e.target).attr('data-click'), $(e.target).attr('data-click-attr')

  constructor: ->
    super
    if @options.parent
      @$el.appendTo @options.parent
    @

  render: ->
    super
    @$container = $(@$('div')[0])
    @
