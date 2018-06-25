view_id = 0

@o.View = class View extends SimpleEvent
  className: null
  el: 'div'
  template: ''
  events: {}

  constructor: (options)->
    @options = _.extend({}, @options_default, options)
    view_id++
    @_id = view_id
    @$el = $("<#{@el}>")
    if @className
      @$el.addClass(@className)
    if @events
      for k, v of @events
        m = k.match /^(\S+)\s*(.*)$/
        @$el.on m[1] + '.delegateEvents' + @_id, m[2], _.bind v, @
    @

  render: (data = {})->
    if @template
      data.self = @
      @$el.html _.template(@template)(data)
    @

  subview_append: (view, events = [])->
    if !@__subview
      @__subview = []
    @__subview.push(view)
    @subview_events_pass(events, view, @)
    view

  subview_events_pass: (events, view, parent = @)->
    events.forEach (ev)=>
      view.bind ev, =>
        parent.trigger ev, arguments[0]

  subview_remove: ->
    if @__subview
      while view = this.__subview.shift()
        view.remove()

  remove: ->
    @subview_remove()
    super
    @$el.off('.delegateEvents' + @_id)
    @$el.remove()

  $: (selector)-> @$el.find(selector)
