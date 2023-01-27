window.o.ViewPopup = class Popup extends window.o.View
  _remove_timeout: 200
  smooth_appear: true
  className: 'popup'
  template: """
    <div>
       <% if (!('close' in self.options) || self.options.close){ %>
        <button data-delay=" &=close_delay " data-action='close' class='popup-close'><%= self.options.close_content || '' %></button>
       <% } %>

       <% if (self.options.head) { %>
        <h1><%= typeof self.options.head === 'function' ? self.options.head({'self': self}) : self.options.head %></h1>
       <% } %>

       <div>
         <% if(self.options.body){ %>
            <%= typeof self.options.body === 'function' ? self.options.body({'self': self}) : self.options.body %>
         <% } %>
         <% if (self.options.actions) { %>

           <div class='popup-actions'>
             <% self.options.actions.forEach(function (button) {
               var event, body;
               if (!button.event) {
                 event = Object.keys(button)[0];
                 body = button[event];
               }
               %><button<% if(button.close_delay){%> disabled='&=close_delay' data-close_delay='&=close_delay' <% } %> data-click='<%= event || button.event %>'<%= button.attr ? ' data-click-attr="' + button.attr + '"' : ''%><%= button.stay ? ' data-stay' : '' %>><%= body || button.body %></button><%
             }); %>

          </div>
         <% } %>
       </div>
    </div>
  """
  options_default:
    close: true
    close_delay: null
    close_content: '×'
    # head: false
    # body: ''
    # actions: [] # {event, attr, stay, body}

  options_bind:
    close_delay: ->
      clearTimeout @__close_delay_timeout
      if @options.close_delay is 0
        return @options_update({close_delay: null})
      if @options.close_delay and @options.close_delay > 0
        @__close_delay_timeout = setTimeout =>
          @options_update {close_delay: @options.close_delay - 1}
        , 1000
  events:
    'click button[data-action="close"]': ->
      @trigger 'close'
      if !@_remove_timeout
        return @remove()
      @$el.attr('data-add', '')
      setTimeout =>
        @remove()
      , @_remove_timeout
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
    clearTimeout @__close_delay_timeout
    super ...arguments

  render: ->
    super ...arguments
    @$container = $(@$('div')[0])
    @
