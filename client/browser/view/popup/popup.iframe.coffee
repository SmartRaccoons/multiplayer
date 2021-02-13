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
    @_resize()
    @_resize_timeout = setTimeout ( => @_resize() ), 1000
    @

  _resize: ->
    if !@options.min_width
      return
    width = @$iframe_parent.width()
    height = @$iframe_parent.height()
    if @options.min_width < width or width < 50
      return
    scale = Math.round(@options.min_width * 100 / width) / 100
    if !@$iframe_wrap
      @$iframe_wrap = $('<div>')
      @$iframe.wrap @$iframe_wrap
    @$iframe_wrap.css
      overlow: 'hidden'
      width: width
      height: height
    @$iframe.css
      'transform-origin': '0 0'
      'transform': "scale(#{1/scale})"
      width: @options.min_width
      height: height * scale

  remove: ->
    clearTimeou @_resize_timeout
    super ...arguments
