@o.ViewCoinsDaily = class CoinsDaily extends @o.View
  className: 'coins-daily'
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
        return "#{_l('coinsdaily.daily')} <button>#{_l('coinsdaily.get')} <span>#{@options.coins}</span></button>"
      "#{_l('coinsdaily.daily')} #{_l('coinsdaily.after')} " + [60 * 60, 60, 1].map (seconds)=>
        if seconds is 1
          return v
        units = Math.floor v / seconds
        v = v - units * seconds
        return units
      .map (v)-> if v < 10 then "0#{v}" else v
      .join ':'
  options_bind:
    left: ->
      clearTimeout @_left_timeout
      if @options.left and @options.left > 0
        @_left_timeout = setTimeout =>
          @options_update {left: @options.left - 1}
        , 1000
  events:
    'click button': -> @trigger 'get'
  remove: ->
    clearTimeout @_left_timeout
    super ...arguments
