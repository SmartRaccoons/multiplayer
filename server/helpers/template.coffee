fs = require('fs')
_template = require('lodash').template

config = {}

module.exports.config = (c)-> config = c
module.exports.config_get = -> config

module.exports.js_get = js_get = (platform, development = false)->
  js = config.javascripts.all.concat(config.javascripts[if development then 'development' else 'master'])
  if platform
    js = js.concat(config.javascripts[platform])
  return js

template_read = (params)->
  fs.readFileSync("#{params.dir or config.dirname}#{params.template}.#{params.extension or 'html'}", 'utf8')

template_read_block = (params)->
  dir = "#{params.dir or config.dirname}block/"
  if !fs.existsSync(dir)
    return {}
  return fs.readdirSync(dir).reduce (acc, file)->
    if file.substr(0, 1) is '.'
      return acc
    acc[file.split('.')[0]] = _template fs.readFileSync("#{dir}#{file}", 'utf8')
    acc
  , {}

_template_include_js = (params)->
  if params.development
    return js_get(params.platform, params.development).map (js)->
      t = js.substr(-3)
      if t is 'css'
        return "<link rel='stylesheet' href='/#{js}' />"
      if t is '.js'
        return "<script src='/#{js}'></script>"
      return "<script>#{js}</script>"
    .join "\n"
  files = []
  if params.platform is 'cordova'
    files.push 'cordova.js'
  files.push "#{params.path_www}d/j-#{params.platform}.js?#{params.version}-#{new Date().getTime()}"
  return """
    #{if params.platform in ['facebook', 'draugiem', 'inbox'] then """

      <script>
          if (!(function () {
            try {
                return window.self !== window.top;
            } catch (e) {
                return true;
            }
          })()) {
              window.location = '/g';
          }
      </script>

    """ else ''}
    #{files.map( (src)-> "<script src='#{src}'></script>" ).join "\n" }
  """

_template_include_css = (params)->
  if params.development
    return "<link rel='stylesheet' href='/client/browser/css/screen.css' />"
  return "<link rel='stylesheet' href='#{params.path_www}d/c.css?#{params.version}-#{new Date().getTime()}' />"


module.exports.generate = (tmp_params)->
  params = Object.assign {}, config, tmp_params
  if params.platform
    params.javascripts = _template_include_js(params)
    params.css = _template_include_css(params)
  params.block = template_read_block(tmp_params)
  params.multiplayer =
    block: template_read_block Object.assign({
        dir: "#{__dirname}/../templates/"
      }, tmp_params)
  _template(template_read(tmp_params))(params)

module.exports.facebook_payment = (template = 'facebook-payment')->
  _facebook_og = _template template_read( { template } )
  ({id, lang, file, price, value, locale, server, type, facebook_id})->
    _str =  "#{type}#{if type isnt 'coins' then " #{id}"  else ''}"
    _facebook_og {
      server
      file
      head: locale._("Facebook.buy head #{_str}", lang, {value})
      desc: locale._("Facebook.buy desc #{_str}", lang, {value})
      price: [ Math.floor(price / 100), price % 100 ].join('.')
      facebook_id
      value
    }

module.exports.generate_local = (template)->
  _template(template_read({template, dir: "#{__dirname}/../templates/"}))
