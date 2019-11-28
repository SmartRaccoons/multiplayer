fs = require('fs')
exec = require('child_process').exec
util = require('util')
exec_promise = util.promisify(exec)


exec_callback = (callback = ->)->
  (error, stdout, stderr)->
    if error
      console.log('exec error: ' + error)
    callback()


exports.compile_file = ({coffee, file, callback})->
  file_parts = file.split('.')
  ext = file_parts.pop()
  if ext is 'coffee'
    exec("#{coffee or './node_modules/coffeescript/bin/coffee -m -c'} #{file}", exec_callback( =>
      callback(file_parts.concat('js').join('.'))
    ))
  if ext is 'sass'
    exec("cd client/browser && compass compile --sourcemap sass/screen.sass -c ../../node_modules/multiplayer/client/browser/config.rb", exec_callback( =>
      callback('client/browser/css/screen.css')
    ))


exports.directory_clear = directory_clear = (path, except = [], dir_main = true)->
  if !fs.existsSync(path)
    return
  fs.readdirSync(path).forEach (file)->
    if except.indexOf(file) >= 0
      return
    curPath = path + '/' + file
    if fs.lstatSync(curPath).isDirectory()
      return directory_clear curPath, [], false
    fs.unlinkSync curPath
  if !dir_main
    fs.rmdirSync path


exports.platform_compile_js = ({platform, babel, uglifyjs, template})->
  fs.writeFileSync "public/d/j-#{platform}.js", template.js_get(platform).map( (f)->
    if f.substr(-3) is '.js'
      return fs.readFileSync(f, 'utf8')
    return f
  ).join("\n")
  Promise.all(
    [
      if babel then babel else null,
      if uglifyjs then uglifyjs else null
    ].filter (ex)-> !!ex
    .map (ex)-> exec_promise "#{ex} public/d/j-#{platform}.js -o public/d/j-#{platform}.js"
  )


exports.platform_compile_css = ({uglifycss})->
  exec_promise "#{uglifycss} client/browser/css/screen.css > public/d/c.css"


exports.platform_compile_html = ({template, params})->
  fs.writeFileSync "public/#{params.platform}.#{params.extension or 'html'}", template.generate(Object.assign({development: false}, params))
