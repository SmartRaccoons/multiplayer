fs = require('fs')
exec = require('child_process').exec
execSync = require('child_process').execSync
util = require('util')
exec_promise = util.promisify(exec)
sass_module = require('sass')
pug = require('pug')


exec_callback = (callback = ->)->
  (error, stdout, stderr)->
    if error
      console.log('exec error: ' + error)
    callback(error)


exports.compile_file = ({coffee, sass, file, file_str, file_out, haml, callback})->
  file_parts = file.split('.')
  ext = file_parts.pop()
  _file_name = file.split('/')
  file_name = _file_name[_file_name.length-1].split('.')[0]
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
        [...file_str.matchAll(/template_pug: """(.*?)"""/sg)].forEach (m)->
          file_str_matched = true
          lines = m[1].split("\n").filter (l)-> l.trim().length > 0
          spaces = lines[0].match /(\s*)/
          if spaces[0]
            spaces_length = spaces[0].length
            lines = lines.map (line)-> line.substr(spaces_length)
          input = lines.join("\n")
          try
            html = pug.render input, {}
          catch e
            console.info input
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
    if sass
      _main_file = if file_name.substr(0, 1) isnt '_' then file_name else 'screen'
      ((opt)=>
        sass_module.render Object.assign(
          {}
          opt
          {
            functions: opt.functions.reduce (acc, fn)->
              if fn is 'image-inline'
                fn =
                  ["#{fn}($str, $style: '')"]: (img_path, style)->
                    extension = img_path.getValue().split('.').pop()
                    img_content = fs.readFileSync "#{opt.pathImage}/#{img_path.getValue()}"
                    if extension is 'svg'
                      extension = 'svg+xml'
                      if style.getValue()
                        img_content = Buffer.from( (img_content + '').replace( /\<style\>.*\<\/style\>/, "<style>#{style.getValue()}</style>" ) )
                    new sass_module.types.String("""url("data:image/#{extension};base64,#{img_content.toString('base64')}")""")
              Object.assign acc, fn
            , {}
          }
        ), (err, result)=>
          if result
            fs.writeFileSync opt.outFile, result.css
            if !opt.embedSourceMap
              fs.writeFileSync "#{opt.outFile}.map", result.map
          if err
            console.info err, opt
          callback(err, opt.outFile)
      )(Object.assign({
        file: "client/browser/sass/#{_main_file}.sass"
        sourceMap: true
        outFile: "client/browser/css/#{_main_file}.css"
        path: 'client/browser/sass'
        pathImage: 'client/browser/images'
        functions: ['image-inline']
      }, sass))

    else
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


exports.platform_compile_css = ({uglifycss, input, output})->
  exec_promise "#{if !uglifycss then 'cat' else uglifycss} client/browser/css/#{input or 'screen'}.css > public/d/#{output or 'c'}.css"


exports.platform_compile_html = ({template, params})->
  fs.writeFileSync "public/#{params.platform}.#{params.extension or 'html'}", template.generate(Object.assign({development: false}, params))
