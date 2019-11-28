glob = require('glob')
platform_compile_css = require('./helpers').platform_compile_css
platform_compile_html = require('./helpers').platform_compile_html
platform_compile_js = require('./helpers').platform_compile_js
compile_file = require('./helpers').compile_file


exports.production = (op, done)->
  op = Object.assign {}, {
    template: {}
    uglifycss: './node_modules/uglifycss/uglifycss'
    uglifyjs: './node_modules/terser/bin/uglifyjs'
    babel: false
  }, op
  template_config = Object.keys(op.template.config_get().javascripts)
  Promise.all( [
      platform_compile_css(op)
    ].concat(
      ['standalone', 'draugiem', 'facebook', 'inbox']
      .filter (platform)-> template_config.indexOf(platform) >= 0
      .map (platform)->
        platform_compile_html {template: op.template, params: {platform, template: 'game'} }
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
      compile_file {file: files_all.shift(), callback: check, coffee: op.coffee}
    check()
  i = 0
  files_all = []
  op.files.forEach (f)->
    glob f, {}, (err, files_one)=>
      i++
      files_all = files_all.concat(files_one)
      if i is op.files.length
        compile()
