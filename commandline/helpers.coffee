fs = require('fs')
exec = require('child_process').exec
execSync = require('child_process').execSync
util = require('util')
exec_promise = util.promisify(exec)


exec_callback = (callback = ->)->
  (error, stdout, stderr)->
    if error
      console.log('exec error: ' + error)
    callback(error)


exports.compile_file = ({coffee, file, file_str, file_out, haml, callback})->
  file_parts = file.split('.')
  ext = file_parts.pop()
  if ext is 'coffee'
    do =>
      if !coffee
        coffee = './node_modules/coffeescript/bin/coffee'
      if !file_out
        file_out = file_parts.concat('js').join('.')
      if file_str
        file_str_matched = true
      else
        file_str = fs.readFileSync(file).toString()
        file_str_matched = false
        [...file_str.matchAll(/template_haml: """(.*)"""/s)].forEach (m)->
          file_str_matched = true
          lines = m[1].split("\n").filter (l)-> l.trim().length > 0
          spaces = lines[0].match /(\s*)/
          if spaces[0]
            spaces_length = spaces[0].length
            lines = lines.map (line)-> line.substr(spaces_length)
          try
            html = execSync( "#{haml or 'haml'} --no-escape-attrs --remove-whitespace -s", { input: lines.join("\n") } )
          catch
            return
          file_str = file_str.replace m[0], 'template: """' + (html + '').trim() + '"""'
      if file_str_matched
        try
          fs.writeFileSync file_out, execSync( "#{coffee} -c -s ", {input: file_str} )
        catch
      else
        try
          execSync "#{coffee} -c -m -o #{file_out} #{file}"
        catch e
          return callback(e, file_out)
      return callback(null, file_out)
  if ext is 'sass'
    exec("cd client/browser && compass compile --sourcemap sass/screen.sass -c ../../node_modules/multiplayer/client/browser/config.rb", exec_callback( (error)=>
      callback(error, 'client/browser/css/screen.css')
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


exports.platform_compile_js = ({platform, babel, uglifyjs, template, include_js})->
  fs.writeFileSync "public/d/j-#{platform}.js", (include_js or []).concat( template.js_get(platform) ).map( (f)->
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
  exec_promise "#{if !uglifycss then 'cat' else uglifycss} client/browser/css/screen.css > public/d/c.css"


exports.platform_compile_html = ({template, params})->
  fs.writeFileSync "public/#{params.platform}.#{params.extension or 'html'}", template.generate(Object.assign({development: false}, params))
