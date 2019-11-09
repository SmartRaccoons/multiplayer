fs = require('fs')
directory_clear = require('../helpers').directory_clear
platform_compile_js = require('../helpers').platform_compile_js
platform_compile_css = require('../helpers').platform_compile_css
platform_compile_html = require('../helpers').platform_compile_html


exports.copy = (op, done)->
  op = Object.assign {}, {
    path: 'cordova'
    template: {}
    uglifycss: './node_modules/uglifycss/uglifycss'
    uglifyjs: './node_modules/terser/bin/uglifyjs'
    babel: './node_modules/@babel/cli/bin/babel.js --source-type=script'
    files: []
  }, op
  platform_compile_html
    template: op.template
    params:
      platform: 'cordova'
      template: 'cordova'
  Promise.all([
    platform_compile_css({uglifycss: op.uglifycss})
    platform_compile_js {platform: 'cordova', babel: op.babel, uglifyjs: op.uglifyjs, template: op.template}
  ]).then =>
    path_www = "#{op.path}/www"
    directory_clear(path_www, ['prev', 'prev.html'])
    fs.mkdirSync "#{path_www}/d"
    fs.mkdirSync "#{path_www}/d/images"
    fs.mkdirSync "#{path_www}/d/sounds"
    fs.copyFileSync 'public/cordova.html', "#{path_www}/index.html"
    fs.unlinkSync 'public/cordova.html'
    ['c.css', 'j-cordova.js'].concat(op.files).forEach (f)->
      fs.copyFileSync "public/d/#{f}", "#{path_www}/d/#{f}"
    fs.unlinkSync 'public/d/j-cordova.js'
    done()
