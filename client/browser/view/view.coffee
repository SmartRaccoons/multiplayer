view_id = 0

update_ev = 'options_update'

@o.View = class View extends SimpleEvent
  className: null
  el: 'div'
  template: ''
  events: {}
  options_bind: {}

  constructor: (options)->
    super()
    @options = _.extend(_.cloneDeep(@options_default), options)
    view_id++
    @_id = view_id
    @$el = $("<#{@el}>")
    if @className
      @$el.addClass(@className)
    if @events
      for k, v of @events
        m = k.match /^(\S+)\s*(.*)$/
        @$el.on "#{m[1]}.delegateEvents#{@_id}", m[2].replace('&-', "#{@className}-")
        , if typeof v isnt 'string' then _.bind(v, @) else ((v)=>
          => @[v]()
        )(v)
    @_options_bind = Object.keys(@options_bind).reduce (acc, v)=>
      acc.concat { events: v.split(','), fn: @options_bind[v].bind(@) }
    , []
    @

  options_update: (options, force = false)->
    updated = []
    for k, v of options
      if force or @options[k] isnt v
        @options[k] = v
        updated.push k
    if updated.length is 0
      return
    @_options_bind
    .filter (v)->
      updated.filter( (up)-> v.events.indexOf(up) >= 0 ).length > 0
    .forEach (v)->
      v.fn()
    updated.forEach (option)=> @trigger "#{update_ev}:#{option}"
    @trigger update_ev

  _option_get_from_str: (str)->
    res = str.trim()
    .match /^(?:\&|\&amp;)\=([\w]*)$/
    if res
      return res[1]
    return null

  option_bind_el: (el)=>
    attributes = $(el)[0].attributes
    [0...attributes.length].forEach (i)=>
      option = @_option_get_from_str attributes[i].value
      if !option
        return
      @option_bind_el_attr(el, attributes[i].name, option)()
    option = @_option_get_from_str $(el).html()
    if option
      @option_bind_el_attr(el, 'html', option)()

  option_bind_el_attr: (el, attr, option)=>
    val_get =  => @options[option]
    exec = =>
      val = val_get()
      if attr is 'html'
        return $(el)[attr](val)
      if val is null
        return $(el).removeAttr(attr)
      $(el).attr attr, val
    @bind "#{update_ev}:#{option}", exec
    return exec

  render: ->
    if not @template
      return @
    @_options_bind.forEach (v)-> v.fn()
    @$el.html _.template(@template)({self: @})
    @$el.find('[class]').forEach (el)=>
      $(el).attr('class', $(el).attr('class').replace('&-', "#{@className}-"))
    @$el.find('*').forEach (el)=>
      @option_bind_el(el)
    return @

  subview_append: (view, events = [])->
    if !@__subview
      @__subview = []
    @__subview.push(view)
    @subview_events_pass(events, view, @)
    view

  subview_events_pass: (events, view, parent = @)->
    events.forEach (ev)=>
      view.bind ev, (args)=>
        parent.trigger ev, args

  subview_remove: ->
    if @__subview
      while view = this.__subview.shift()
        view.remove()
  hide: ->
    @$el.addClass('hidden')
    @trigger 'hide'

  show: ->
    @$el.removeClass('hidden')
    @trigger 'show'

  remove: ->
    @subview_remove()
    super ...arguments
    @$el.off('.delegateEvents' + @_id)
    @$el.remove()

  $: (selector)-> @$el.find(selector)
