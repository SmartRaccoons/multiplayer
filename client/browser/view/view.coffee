view_id = 0

update_ev = 'options_update'


touch = ('ontouchstart' of window) or (navigator.MaxTouchPoints > 0) or (navigator.msMaxTouchPoints > 0)


@o.View = class View extends SimpleEvent
  className: null
  el: 'div'
  template: ''
  events: {}
  options_html: {}
  options_bind: {}
  options_bind_el_self: {} # or []

  constructor: (options)->
    super()
    @__touch = touch
    @options = _.extend(_.cloneDeep(@options_default), options)
    view_id++
    @_id = view_id
    @$el = $("<#{@el}>")
    if @className
      @$el.addClass(@className)
    @__events_delegate()
    @__events_binded_el = []
    @_options_bind = Object.keys(@options_bind).reduce (acc, v)=>
      acc.concat { events: v.split(','), fn: @options_bind[v].bind(@) }
    , []
    @

  __events_delegate: ->
    if !@events
      return
    for k, v of @events
      m = k.match /^(\S+)\s*(.*)$/
      fn = if typeof v isnt 'string' then _.bind(v, @) else ((v)=>
        => @[v]()
      )(v)
      el = @__selector_parse(m[2], true)
      m[1].split(',').forEach (event)=>
        [ev, pr] = event.split(':')
        if pr is 'nt' and @__touch
          return
        if pr is 't' and !@__touch
          return
        if ev is 'click' and @__touch
          ev = 'touchstart'
        @$el.on "#{ev}.delegateEvents#{@_id}", el, fn

  __events_undelegate: -> @$el.off('.delegateEvents' + @_id)

  options_update: (options, force = false)->
    updated = []
    for k, v of options
      if force or !_.isEqual(@options[k], v)
        @options[k] = v
        updated.push k
    if updated.length is 0
      return
    @_options_bind
    .concat @_subview_options_binded()
    .filter (v)->
      updated.filter( (up)-> v.events.indexOf(up) >= 0 ).length > 0
    .forEach (v)->
      v.fn()
    updated.forEach (option)=> @trigger "#{update_ev}:#{option}"
    @trigger update_ev

  options_update_bind: (option, exec)-> @bind "#{update_ev}:#{option}", exec

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
    val_get = if @options_html[option] then => @options_html[option].bind(@)(@options[option]) else => @options[option]
    exec = =>
      val = val_get()
      if attr is 'html'
        return $(el)[attr](val)
      if val is null or val is false
        return $(el).removeAttr(attr)
      $(el).attr attr, val
    @bind "#{update_ev}:#{option}", exec
    @__events_binded_el.push "#{update_ev}:#{option}"
    return exec

  render: ->
    if @__rendering or not @template
      return @
    @__rendering = true
    do =>
      while ev = @__events_binded_el.shift()
        @unbind(ev)
    @_options_bind.forEach (v)-> v.fn()
    @$el.html _.template(@template)({self: @})
    @$el.find('[class]').forEach (el)=>
      $(el).attr 'class', @__selector_parse($(el).attr('class'))
    do =>
      get = =>
        if !Array.isArray(@options_bind_el_self)
          return @options_bind_el_self
        opt = {}
        @options_bind_el_self.forEach (v)-> opt["data-#{v}"] = v
        return opt
      for attr, option of get()
        @option_bind_el_attr(@$el, attr, option)()
    @$el.find('*').forEach (el)=>
      @option_bind_el(el)
    @__rendering = false
    return @

  subview_append: (view, events = [], options_bind = {})->
    if !@__subview
      @__subview = []
    @__subview.push(view)
    @subview_events_pass(events, view, @)
    if Array.isArray(options_bind)
      options_bind = options_bind.reduce (acc, v)->
        Object.assign acc, {[v]: v}
      , {}
    view._options_bind_parent = Object.keys(options_bind).reduce (acc, key)=>
      value = options_bind[key]
      fn = => view.options_update { [value]: @options[key] }
      fn()
      acc.concat {events: key.split(','), fn}
    , []
    view

  _subview_options_binded: ->
    if !@__subview
      return []
    @__subview.reduce (acc, v)=>
      acc.concat v._options_bind_parent
    , []

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
    @

  show: ->
    @$el.removeClass('hidden')
    @trigger 'show'
    @

  show_hide: ->
    if @$el.hasClass('hidden')
      return @show()
    @hide()

  hide_show: -> @show_hide()

  remove: ->
    @subview_remove()
    super ...arguments
    @__events_undelegate()
    @$el.remove()

  __selector_parse: (s, point = false)-> s.replace '&-', "#{if point then '.' else ''}#{@className}-"

  $: (selector)-> @$el.find(@__selector_parse(selector, true))
