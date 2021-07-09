cordova = -> !!window.cordova


__ids = 0
class SoundMedia extends SimpleEvent
  constructor: (@options)->
    super()
    __ids++
    @id = __ids
    @cordova = cordova()
    @media = if @cordova then new Media(@options.url) else new Audio(@options.url)
    if !@cordova
      @media.addEventListener 'loadeddata', =>
        @_duration_mls = Math.round @media.duration * 1000
        @trigger 'loadeddata'
    @volume(@options.volume)
    @__remove_callback = setTimeout =>
      @remove()
    , 1000 * 60 * 5
    @

  duration: (callback, binded = false)->
    if @_duration_mls
      return callback(@_duration_mls)
    if binded
      return callback(0)
    @bind 'loadeddata', => @duration(callback, true)

  volume: (volume)->
    @options.volume = volume
    if @options.volume < 0
      @options.volume = 0
    rounded = Math.round(@options.volume * 100) / 100
    if @cordova
      @media.setVolume("#{rounded}")
    else
      @media.volume = rounded
    @

  play: ->
    if @cordova
      @media.play({ playAudioWhenScreenIsLocked: false })
    else
      @media.play()
    @

  stop: ->
    @volume(0)
    if @cordova
      @media.stop()
    @

  fade_out: (mls, mls_left, volume = @options.volume, start = new Date().getTime())->
    if !mls_left
      mls_left = mls
    window.requestAnimationFrame =>
      end = new Date().getTime()
      diff = end - start
      if (mls_left - diff) <= 0
        return @remove()
      @volume volume * mls_left / mls
      @fade_out(mls, mls_left - diff, volume, end)

  remove: ->
    clearTimeout @__remove_callback
    @stop()
    if @cordova
      @media.release()
    @media = null
    super()


__enable = true
@o.Sound = class Sound
  constructor: (@options)->
    @__medias = []
    @__muted = if Cookies? then !!parseInt(Cookies.get('__sound_muted')) else false
    fn = =>
      @__enable = true
      document.body.removeEventListener('click', fn)
      document.body.removeEventListener('touchstart', fn)
    document.body.addEventListener('click', fn)
    document.body.addEventListener('touchstart', fn)

  _media_get: (sound)->
    if !__enable
      return
    if !@__enable
      return
    if @__muted
      return
    try
      media = new SoundMedia({
        volume: @options.volume
        url: "#{@options.path}#{sound}.#{@options.extension}"
      })
      @__medias.push media
      media.on 'remove', =>
        @__medias.splice @get(media.id, true), 1
      return media
    catch
      return null

  duration: (sound, callback)->
    media = @_media_get(sound)
    if !media
      return
    media.duration(callback)

  play: (sound)->
    media = @_media_get(sound)
    if !media
      return
    media.play()

  get: (id, index = false)-> @__medias[if index then 'findIndex' else 'find']( (m)-> m.id is id )

  is_enable: -> __enable

  disable: ->
    @clear()
    __enable = false

  fade: (media)->
    if media
      @get(media.id).fade_out(@options.fade_out)

  clear: ->
    @__medias.map (m)-> m.id
    .forEach (id)=> @get(id).remove()

  is_mute: -> @__muted

  mute: (@__muted)->
    @clear()
    if Cookies?
      Cookies.set('__sound_muted', if @__muted then 1 else 0)
