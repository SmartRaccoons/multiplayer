@o.Sound = class Sound
  constructor: (@options)->
  play: (sound)->
    try
      a = new Audio("#{@options.path}#{sound}.wav")
      a.volume = 0.3
      a.play()
    catch
