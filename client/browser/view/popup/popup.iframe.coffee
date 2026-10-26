Popup = window.o.ViewPopup


window.o.ViewPopupIframe = class PopupAuthorize extends Popup
  className: Popup::className + '-iframe'
  options_default:
    close: true
    body: _.template """
      <iframe frameborder='0' src='<%= self.options.link %>' style='width:100%;height:100%;'>
    """
  render: ->
    super ...arguments
    @$iframe = @$('iframe')
    @$iframe_parent = @$iframe.parent()
    if !@_resize_fn
      @_resize_fn = => @_resize()
      window.addEventListener 'resize', @_resize_fn
    @_resize()
    @_resize_timeout = setTimeout ( => @_resize() ), 1000
    @

  _resize: ->
    if !@options.min_width and !@options.min_height
      return
    width = @$iframe_parent.width()
    height = @$iframe_parent.height()
    if !(width >= 50) or !(height >= 50)
      return
    scale = 1
    if @options.min_width and width < @options.min_width
      scale = @options.min_width / width
    if @options.min_height and height < @options.min_height
      scale = Math.max scale, @options.min_height / height
    scale = Math.round(scale * 100) / 100
    # never scale below 0.5 visually
    scale = 2 if scale > 2
    if scale is 1 and !@$iframe_wrap
      return
    if !@$iframe_wrap
      @$iframe_wrap = $('<div>')
      @$iframe.wrap @$iframe_wrap
    @$iframe_wrap.css
      overflow: 'hidden'
      width: width
      height: height
    @$iframe.css
      'transform-origin': '0 0'
      'transform': "scale(#{1/scale})"
      width: width * scale
      height: height * scale

  remove: ->
    clearTimeout @_resize_timeout
    if @_resize_fn
      window.removeEventListener 'resize', @_resize_fn
      @_resize_fn = null
    super ...arguments
