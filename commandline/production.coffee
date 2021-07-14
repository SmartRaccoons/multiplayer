fs = require('fs')
glob = require('glob')
platform_compile_css = require('./helpers').platform_compile_css
platform_compile_html = require('./helpers').platform_compile_html
platform_compile_js = require('./helpers').platform_compile_js
compile_file = require('./helpers').compile_file


exports.production = (op, done)->
  op = Object.assign {}, {
    template: {}
    uglifyjs: './node_modules/terser/bin/uglifyjs'
    babel: './node_modules/@babel/cli/bin/babel.js --source-type=script'
  }, op
  template_config = Object.keys(op.template.config_get().javascripts)
  platforms = ['standalone', 'draugiem', 'facebook', 'inbox', 'vkontakte']
    .filter (platform)-> template_config.indexOf(platform) >= 0
  Promise.all( [
      new Promise (resolve, reject)->
        platforms.forEach (platform)->
          platform_compile_html {template: op.template, params: {platform, template: 'game', path_www: '/'} }
        resolve()
      platform_compile_css(op)
    ].concat(
      platforms.map (platform)->
        platform_compile_js Object.assign( {platform}, op )
    )
  ).then => done()

exports.compile = (op, done)->
  op = Object.assign {}, {
    files: []
  }, op
  compile = ->
    check = ->
      if files_all.length is 0
        return done()
      compile_file {file: files_all.shift(), callback: check, coffee: op.coffee, sass: op.sass}
    check()
  i = 0
  files_all = []
  op.files.forEach (f)->
    glob f, {}, (err, files_one)=>
      i++
      files_all = files_all.concat(files_one)
      if i is op.files.length
        compile()

exports.facebook_payment = ({ template, config_local, locale }, done)->
  Object.keys(config_local.facebook.buy_price).forEach (id)->
    config_local.locales.forEach (lang)->
      file = "service-#{id}-#{lang}"
      type = if id in config_local.buy.coins then 'coins' else if config_local.buy.subscription and id in Object.keys(config_local.buy.subscription) then 'subscription' else 'product'
      tml = template.facebook_payment "facebook-#{type}"
      fs.writeFileSync "public/d/og/#{file}.html", tml({
        id, lang, file, type, locale,
        value: if type is 'subscription' then config_local.buy.subscription[id] else config_local.buy.product[id]
        server: config_local.server
        price: config_local.facebook.buy_price[id]
        facebook_id: config_local.facebook.id
      })
  done()
