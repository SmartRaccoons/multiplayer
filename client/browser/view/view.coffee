view_id = 0

update_ev = 'options_update'


touch = ('ontouchstart' of window) or (navigator.MaxTouchPoints > 0) or (navigator.msMaxTouchPoints > 0)

__body = new SimpleEvent()
$('body').on 'click', -> __body.trigger 'click'
if touch
  $('body').addClass('touch')



@o.View = class View extends SimpleEvent
  background_click_hide: false
  smooth_appear: false
  className: null
  el: 'div'
  template: ''
  events: {}
  options_html: {}
  #   data-s=' &=attr&attr2 '
  #   data-s=' &=options_html[1] '
  options_bind: {}
  options_bind_el_self: {} # or []
  options_pre: {}

  constructor: (options = {})->
    super()
    @__touch = touch
    @options = _.extend _.cloneDeep(@options_default), _.omit(options, ['el'])
    view_id++
    @_id = view_id
    @$el = options.el or $("<#{@el}>")
    if @className
      @$el.addClass(@className)
    @__events_delegate()
    @__events_binded_el = []
    @__options_bind = Object.keys(@options_bind).sort().reduce (acc, v)=>
      acc.concat { events: v.split(','), fn: @options_bind[v].bind(@) }
    , []
    @

  options_default_over: (options, options_default = Object.keys(@options_default))->
    @options_update _.extend( _.cloneDeep( _.pick(@options_default, options_default) ), options )

  __events_delegate: ->
    if !@events
      return
    Object.keys(@events).sort().forEach (event_params)=>
      fn = @events[event_params]
      event_match = event_params.match /^(\S+)\s*(.*)$/
      fn_binded = if typeof fn isnt 'string' then _.bind(fn, @) else ((fn)=>
        => @[fn]()
      )(fn)
      el_str = @__selector_parse(event_match[2], true)
      if el_str.substr(0, 1) is '&'
        ((self)->
          el_str_parse = el_str.substr(1).split(' ')
          el_str = el_str_parse[1]
          fn_binded_prev = fn_binded
          fn_binded = ->
            if self.$el.is(el_str_parse[0])
              fn_binded_prev.apply(@, arguments)
        )(@)
      event_match[1].split(',').forEach (event)=>
        [ev, pr] = event.split(':')
        if pr is 'nt' and @__touch
          return
        if pr is 't' and !@__touch
          return
        @$el.on "#{ev}.delegateEvents#{@_id}", el_str, fn_binded

  __events_undelegate: -> @$el.off('.delegateEvents' + @_id)

  options_update: (options, force = false)->
    previous = {}
    for k, v of options
      if force or !_.isEqual(@options[k], v)
        previous[k] = _.cloneDeep(@options[k])
        @options[k] = if @options_pre[k] then @options_pre[k].bind(@)(v) else v
    if Object.keys(previous).length is 0
      return
    @__options_bind
    .concat (@__views or []).reduce(
      (acc, view)=>
        view_filter = (view.__subview_options_binded or []).filter (event)=> event.id is @_id
        acc.concat (view.__subview_options_binded or [])
    , [])
    .filter (v)->
      Object.keys(previous).filter( (up)-> v.events.indexOf(up) >= 0 ).length > 0
    .forEach (v)->
      v.fn(previous)
    Object.keys(previous).forEach (option)=> @trigger "#{update_ev}:#{option}"
    @trigger update_ev

  options_update_bind: (option, exec)-> @bind "#{update_ev}:#{option}", => exec(@options[option])

  options_update_unbind: (option, exec = null)-> @unbind "#{update_ev}:#{option}", exec

  __option_get_from_str: (str)->
    res = str.trim()
    .replace '&amp;', '&'
    .match /^(?:\&)\=([\w\.&\]\[]*)$/
    if res
      return res[1]
    return null

  option_bind_el: (el)=>
    attributes = $(el)[0].attributes
    [0...attributes.length].map (i)=>
      {
        option: @__option_get_from_str attributes[i].value
        name: attributes[i].name
      }
    .filter ({option})-> !!option
    .forEach ({name, option})=> @option_bind_el_attr(el, name, option)()
    option = @__option_get_from_str $(el).html()
    if option
      @option_bind_el_attr(el, 'html', option)()

  option_bind_el_attr: (el, attr, option)=>
    # check is array
    arrayed = option.match /^([\w]*)\[([\d]*)\]$/
    if arrayed
      option = arrayed[1]
    opt_get = =>
      op = @options
      for v in option.split('.')
        op = op[v]
        if op is null
          break
      return op
    val_get = if @options_html[option] then =>
      (if arrayed then @options_html[option][arrayed[2]] else @options_html[option])
      .bind(@)(opt_get())
    else =>
      opt_get()
    if option.indexOf('&') >= 0
      options = option.split '&'
      val_get = do (options)=>
        =>
          options.filter( (option)=> @options[option] ).length is options.length
    else if option.indexOf('.') >= 0
      options = [ option.split('.')[0] ]
    else
      options = [option]
    exec = =>
      val = val_get()
      if attr is 'html'
        return $(el)[attr](val)
      if !val? or val is false
        return $(el).removeAttr(attr)
      $(el).attr attr, val
    options.forEach (option)=>
      @bind "#{update_ev}:#{option}", exec
      @__events_binded_el.push "#{update_ev}:#{option}"
    return exec

  render: ->
    @subview_remove()
    if @__rendering
      return @
    @__rendering = true
    do =>
      while ev = @__events_binded_el.shift()
        @unbind(ev)
    @__options_bind.forEach (v)=> v.fn(@options)
    if !@template_compiled
      if @template
        @template_compiled = _.template(@template)
    if @template_compiled
      @$el.html @template_compiled({self: @})
    @$el.find('[class]').forEach (el)=>
      $(el).attr 'class', @__selector_parse($(el).attr('class'))
    do =>
      get = =>
        if !Array.isArray(@options_bind_el_self)
          return @options_bind_el_self
        @options_bind_el_self.reduce (acc, v)->
          Object.assign acc, {["data-#{v}"]: v}
        , {}
      for attr, option of get()
        @option_bind_el_attr(@$el, attr, option)()
    @$el.find('*').forEach (el)=>
      @option_bind_el(el)
    @__rendering = false
    if @smooth_appear
      @$el.attr('data-add', '')
      @$el.height()
      @$el.removeAttr('data-add')
    return @

  subview_append: (view, events = [], options_bind = {})->
    if !@__subview
      @__subview = []
    @__subview.push(view)
    @subview_events_pass(events, view)
    @subview_options_bind(options_bind, view)
    view

  subview_options_bind: (options_bind, view, parent = @)->
    if Array.isArray(options_bind)
      options_bind = options_bind.reduce (acc, v)->
        Object.assign acc, {[v]: v}
      , {}
    parent.__views = (parent.__views or []).concat view
    view.__subview_options_binded = Object.keys(options_bind).reduce (acc, key)=>
      value = options_bind[key]
      fn = =>
        view.options_update { [value]: parent.options[key] }, true
      fn()
      acc.concat {events: key.split(','), fn, id: parent._id}
    , view.__subview_options_binded or []
    view.on 'remove', =>
      if parent.__views
        parent.__views = parent.__views.filter (v)-> v._id isnt view._id
    parent.on 'remove', =>
      if view.__subview_options_binded
        view.__subview_options_binded = view.__subview_options_binded.filter (event)-> event.id isnt parent._id
    @

  subview_events_pass: (events, view, parent = @)->
    events.forEach (ev)=>
      view.bind ev, (args)=>
        parent.trigger ev, args

  subview_remove: ->
    if @__subview
      while view = this.__subview.shift()
        view.remove()
  hide: ->
    @__background_click_callback_remove()
    @$el.addClass('hidden')
    @trigger 'hide'
    @

  __is_visible: -> !@$el.hasClass('hidden')

  show: ->
    @$el.removeClass('hidden')
    @trigger 'show'
    if @background_click_hide
      @__background_click_callback_add(@hide.bind(@))
    @

  show_hide: ->
    if !@__is_visible()
      return @show()
    @hide()

  hide_show: -> @show_hide()

  __background_click_callback_add: (callback)->
    @__background_click_callback_remove()
    setTimeout =>
      # it is timeout beacause bubbled to body click event
      if @__removed
        return
      @__background_click_callback = -> callback()
      __body.bind 'click', @__background_click_callback
    , 0

  __background_click_callback_remove: ->
    if @__background_click_callback
      __body.unbind 'click', @__background_click_callback
      @__background_click_callback = null

  remove: ->
    @__removed = true
    @__background_click_callback_remove()
    @subview_remove()
    super ...arguments
    @__events_undelegate()
    delete @__subview_options_binded
    @$el.remove()

  __selector_parse: (s, point = false)->
    s.replace /&-/g, "#{if point then '.' else ''}#{@className}-"
    .replace /--/g, "#{if point then '.' else ''}#{@className}-"

  $: (selector)-> @$el.find(@__selector_parse(selector, true))
