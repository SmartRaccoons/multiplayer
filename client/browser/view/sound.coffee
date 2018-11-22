@o.Sound = class Sound
  constructor: (@options)->
    @_media_last = null
    @__muted = false
    fn = =>
      @__enable = true
      document.body.removeEventListener('click', fn)
    document.body.addEventListener('click', fn)

  play: (sound)->
    if !@__enable
      return
    if @__muted
      return
    try
      @_media_last = new Audio("#{@options.path}#{sound}.wav")
      @_media_last.volume = 0.3
      @_media_last.play()
    catch

  stop: ->
    if @_media_last
      @_media_last.volume = 0

  is_mute: -> @__muted

  mute: (@__muted)-> @stop()
