cordova = -> !!window.cordova


__ids = 0
class SoundMedia extends SimpleEvent
  constructor: (options)->
    super()
    @options = Object.assign {
      volume: 0
      volume_prev: 0
    }, options
    __ids++
    @id = __ids
    @cordova = cordova()
    @media = do =>
      if @cordova
        return new Media(@options.url)
      return new Howl({
        src: [@options.url]
        loop: @options.loop
      })
    if !@cordova
      @media.once 'load', =>
        @_duration_mls = Math.round @media.duration() * 1000
        @trigger 'loadeddata'
    if @options.fade_in
      @fade_in(if typeof @options.fade_in is 'number' then @options.fade_in)
    else
      @volume(@options.volume)
    if !@options.loop
      @__remove_callback = setTimeout =>
        @remove()
      , 1000 * 30
    @

  duration: (callback)->
    if @_duration_mls
      return callback(@_duration_mls)
    @bind 'loadeddata', =>
      @duration =>
        callback @_duration_mls or 0

  volume: (volume)->
    @options.volume_prev = @options.volume
    @options.volume = volume
    if @options.volume < 0
      @options.volume = 0
    rounded = Math.round(@options.volume * 100) / 100
    if @cordova
      @media.setVolume("#{rounded}")
    else
      @media.volume(rounded)
    @

  play: ->
    if @cordova
      @media.play Object.assign(
        { playAudioWhenScreenIsLocked: false }
        if @options.loop then {numberOfLoops: 111}
      )
    else
      @media.play()
    @

  stop: ->
    @volume(0)
    if @cordova
      @media.stop()
    else
      @media.stop()
    @

  fade: (volume_end = 0, volume_start = @options.volume, mls = 1000, remove = true)->
    start = new Date().getTime()
    fade = =>
      window.requestAnimationFrame =>
        if !@media
          return
        mls_left = mls - (new Date().getTime() - start )
        if mls_left <= 0
          if remove
            @remove()
          return
        @volume volume_start + (volume_end - volume_start) * (1 - mls_left / mls)
        fade()
    fade()

  fade_out: (mls)-> @fade(0, @options.volume, mls)

  fade_in: (mls)-> @fade(@options.volume, 0, mls, false)

  remove: ->
    clearTimeout @__remove_callback
    @stop()
    if @cordova
      @media.release()
    else
      @media.unload()
    @media = null
    super()


__enable = true
__iteraction = false
@o.Sound = class Sound extends SimpleEvent
  constructor: (@options)->
    super ...arguments
    @__medias = []
    @__muted = if Cookies? then !!parseInt(Cookies.get('__sound_muted')) else false
    enable = =>
      __iteraction = true
      @trigger 'enable'
    if cordova()
      setTimeout =>
        enable()
      , 100
    else
      fn = =>
        __iteraction = true
        @trigger 'enable'
        document.body.removeEventListener('click', fn)
        document.body.removeEventListener('touchstart', fn)
      document.body.addEventListener('click', fn)
      document.body.addEventListener('touchstart', fn)
      document.addEventListener 'visibilitychange', =>
        if document.hidden
          @_mute_medias()
        else
          @_unmute_medias()
    @

  _media_create: (params)->
    if !__enable
      return
    if !__iteraction
      return
    if @__muted
      return
    try
      params = if typeof params is 'object' then params else {sound: params}
      @trigger 'play', params.sound
      media = new SoundMedia Object.assign({
        volume: @options.volume
        url: "#{@options.path}#{params.sound}.#{@options.extension}"
      }, params)
      @__medias.push media
      media.on 'remove', =>
        @__medias.splice @get(media.id, true), 1
      return media
    catch
      return null

  play: (sound)->
    media = @_media_create(sound)
    if !media
      return
    media.play()
    media

  get: (id, index = false)-> @__medias[if index then 'findIndex' else 'find']( (m)-> m.id is id )

  is_enable: -> __enable

  disable: ->
    @_clear()
    __enable = false

  enable: ->
    __enable = true

  _clear: ->
    @__medias.map (m)-> m.id
    .forEach (id)=> @get(id).remove()

  _mute_medias: ->
    @__medias.map (m)-> m.id
    .forEach (id)=> @get(id).volume(0)

  _unmute_medias: ->
    @__medias.map (m)-> m.id
    .forEach (id)=> @get(id).volume(@get(id).options.volume_prev)

  is_mute: -> @__muted

  mute: (@__muted)->
    @_clear()
    if Cookies?
      Cookies.set('__sound_muted', if @__muted then 1 else 0)
    @trigger 'mute', @__muted
