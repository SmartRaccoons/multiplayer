fn = (key, active = 'en', subparams)->
  res = locales[active][key]
  if not subparams
    return res
  res.replace /\\?\{([^{}]+)\}/g, (match, name) ->
    if match.charAt(0) == '\\'
      return match.slice(1)
    if subparams[name]
      return subparams[name]
    return ''

locales = {}
is_node = !@o
if is_node
  fs = require('fs')
(exports ? @o).Locale = Locale =
  config: (config)->
    ['en', 'lv', 'ru', 'lg'].forEach (language)->
      if not is_node
        if @o["Locale#{language}"]
          locales[language] = @o["Locale#{language}"]
        return
      else
        if fs.existsSync "#{config.dirname}#{language}"
          locales[language] = require("#{config.dirname}#{language}")["Locale#{language}"]
    @keys = Object.keys(locales)
  validate: (lang)->
    if lang
      for l in @keys
        if l is lang.substr(0, l.length)
          return l
    return @keys[0]

if is_node
  exports._ = fn
else
  do =>
    Locale.config()
    App.lang = do ->
      for lang in Locale.keys
        for param in ['lang', 'language']
          if window.location.href.indexOf("#{param}=#{lang}") >= 0
            return lang
      Locale.keys[0]
    @._l = (key, subparams)-> fn(key, App.lang, subparams)
