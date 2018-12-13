cordova = -> !!window.cordova

@o.Sound = class Sound
  _volume: 0.3
  constructor: (@options)->
    @_media_last = null
    @__muted = false
    fn = =>
      @__enable = true
      document.body.removeEventListener('click', fn)
      document.body.removeEventListener('touchstart', fn)
    document.body.addEventListener('click', fn)
    document.body.addEventListener('touchstart', fn)

  play: (sound)->
    if !@__enable
      return
    if @__muted
      return
    try
      if cordova()
        if @_media_last
          @_media_last.release()
        @_media_last = new Media("#{@options.path}#{sound}.wav")
        @_media_last.setVolume("#{@_volume}")
      else
        @_media_last = new Audio("#{@options.path}#{sound}.wav")
        @_media_last.volume = @_volume
      @_media_last.play()
    catch

  stop: ->
    if !@_media_last
      return
    if cordova()
      @_media_last.setVolume('0')
    else
      @_media_last.volume = 0

  is_mute: -> @__muted

  mute: (@__muted)-> @stop()
