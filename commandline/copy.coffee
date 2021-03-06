fs = require('fs')
directory_clear = require('./helpers').directory_clear
directory_create = require('./helpers').directory_create
platform_compile_js = require('./helpers').platform_compile_js
platform_compile_css = require('./helpers').platform_compile_css
platform_compile_html = require('./helpers').platform_compile_html


exports.copy = (op, done)->
  op = Object.assign {}, {
    platform: 'cordova'
    platform_template: 'cordova'
    path: 'cordova/www'
    path_www: ''
    template: {}
    uglifycss: './node_modules/uglifycss/uglifycss'
    uglifyjs: ({input, output})-> "./node_modules/terser/bin/terser #{input} -c -m -o #{output}"
    babel: './node_modules/@babel/cli/bin/babel.js --source-type=script'
    files: []
  }, op
  platform_compile_html
    template: op.template
    params:
      platform: op.platform
      template: op.platform_template
      path_www: op.path_www
  Promise.all([
    platform_compile_css({uglifycss: op.uglifycss})
    platform_compile_js op
  ]).then =>
    directory_clear(op.path, ['prev', 'prev.html'])
    fs.mkdirSync "#{op.path}/d"
    fs.mkdirSync "#{op.path}/d/images"
    fs.mkdirSync "#{op.path}/d/sounds"
    fs.copyFileSync "public/#{op.platform}.html", "#{op.path}/index.html"
    fs.unlinkSync "public/#{op.platform}.html"
    ['c.css', "j-#{op.platform}.js"].concat(op.files).forEach (f)->
      directory_create "#{op.path}/d/#{f}"
      fs.copyFileSync "public/d/#{f}", "#{op.path}/d/#{f}"
    fs.unlinkSync "public/d/j-#{op.platform}.js"
    done()
