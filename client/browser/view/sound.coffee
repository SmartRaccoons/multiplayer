@o.Sound = class Sound
  constructor: (@options)->
    @__muted = false

  play: (sound)->
    if @__muted
      return
    try
      a = new Audio("#{@options.path}#{sound}.wav")
      a.volume = 0.3
      a.play()
    catch

  is_mute: -> @__muted

  mute: (@__muted)->
