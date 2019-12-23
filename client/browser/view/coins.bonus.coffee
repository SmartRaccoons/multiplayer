@o.ViewCoinsBonus = class CoinsBonus extends @o.View
  className: 'coins-bonus'
  template: """
    <span> &=left </span>
  """
  options_default:
    left: null
  options_html:
    left: (v)->
      if v is null
        return ''
      if v is 0
        return _l("coinsbonus.#{@type}.get", {coins: @options.coins})

  events:
    'click button': 'get'

  get: -> @trigger 'get'


@o.ViewCoinsBonusTimed = class CoinsBonusTimed extends CoinsBonus
  template: """
    <span> &=left_updated </span>
  """
  options_html:
    left_updated: (v)->
      if v and v > 0
        return _l("coinsbonus.#{@type}.wait", {
          time: [60 * 60, 60, 1].map (seconds)=>
              if seconds is 1
                return v
              units = Math.floor v / seconds
              v = v - units * seconds
              return units
            .map (v)-> if v < 10 then "0#{v}" else v
            .join ':'
        })
      return CoinsBonus::options_html['left'].apply(@, [v])
  options_bind:
    left: ->
      @_start_timer = new Date()
      clearTimeout @_left_timeout
      @options_update { left_updated: @options.left }
      if @options.left is null or @options.left is 0
        return
      update = =>
        @_left_timeout = setTimeout =>
          left_updated = @options.left - Math.round( ( new Date().getTime() - @_start_timer.getTime() ) / 1000 )
          if left_updated < 0
            left_updated = 0
          @options_update { left_updated }
          if left_updated > 0
            update()
        , 1000
      update()

  remove: ->
    clearTimeout @_left_timeout
    super ...arguments
