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
  options_html:
    left: (v)->
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
      clearTimeout @_left_timeout
      if @options.left and @options.left > 0
        @_left_timeout = setTimeout =>
          @options_update {left: @options.left - 1}
        , 1000

  remove: ->
    clearTimeout @_left_timeout
    super ...arguments
