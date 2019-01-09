coffeescript = require('coffeescript')
fs = require('fs')
translate_fn_generate = require('./fn').translate_fn_generate


locales = {}
locales_available = []
translate_fn = -> throw 'no translate fn'

module.exports.config = (config)->
  get_config = (f)->
    try
      return require("#{config.dirname}/#{f}")
    catch e
      return false
  locales = {}
  locales_available = config.locales.slice(0)
  locale_default = get_config('en')
  locales_available.forEach (language)->
    language_common = get_config(language)
    ['server', 'client'].forEach (platform)->
      language_platform = get_config("#{language}.#{platform}")
      if !locales[language]
        locales[language] = {}
      locales[language][platform] = Object.assign({}, locale_default, language_common, language_platform)

  translate_fn = translate_fn_generate(
    Object.keys(locales)
    .reduce (acc, language)->
      acc[language] = locales[language].server
      acc
    , {}
  )

module.exports.client = ->
  locales_var = Object.keys(locales)
    .map (language)->
      "locales['#{language}'] = #{JSON.stringify(locales[language].client)}"
    .join("\n")
  coffeescript.compile """
    locales_available = #{JSON.stringify(locales_available)}
    locales = {}
    #{locales_var}
    #{fs.readFileSync("#{__dirname}/fn.coffee")}
    fn = translate_fn_generate(locales)
    App.lang = do =>
      for lang in Object.keys(locales)
        for param in ['lang', 'language']
          if window.location.href.indexOf(param + '=' + lang) >= 0
            return lang
      @._locales_default = true
      locales_available[0]

    @._l = (key, subparams)-> fn(key, App.lang, subparams)
    @._locales_available = locales_available.map (language)-> [language, locales[language]['Language']]
  """

module.exports.validate = (lang)->
  if lang
    for l in locales_available
      if l is lang.substr(0, l.length)
        return l
  return locales_available[0]

module.exports.lang_short = (lang)-> locales[lang].server.id

module.exports.lang_long = (short)->
  for lang, locale of locales
    if locale.server.id is short
      return lang
  return locales_available[0]

module.exports._ = -> translate_fn.apply(@, arguments)
