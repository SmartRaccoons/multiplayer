fs = require('fs')
exec = require('child_process').exec
glob = require('glob')


deleteFolderRecursive = (path)->
  if !fs.existsSync(path)
    return
  fs.readdirSync(path).forEach (file)->
    curPath = path + '/' + file
    if fs.lstatSync(curPath).isDirectory()
      return deleteFolderRecursive curPath
    fs.unlinkSync curPath
  fs.rmdirSync path


module.exports = (grunt, template, commands)->
  grunt.loadNpmTasks('grunt-contrib-watch')
  coffee = [
    'client/*.coffee'
    'client/**/*.coffee'
  ]
  exec_callback = (callback)->
    (error, stdout, stderr)->
      if error
        console.log('exec error: ' + error)
      callback()

  platform_compile_js = (platform, done)=>
    fs.writeFileSync 'all-temp.js', template.js_get(platform).map( (f)->
      if f.substr(-3) is '.js'
        return fs.readFileSync(f, 'utf8')
      return f
    ).join("\n")
    exec "#{commands.uglifyjs} all-temp.js -o public/d/j-#{platform}.js", (err)=>
      if err
        console.info err
        return done()
      exec "rm all-temp.js", => done()

  platform_compile_css = =>
    exec "#{commands.uglifycss} client/browser/css/screen.css > public/d/c.css"

  platform_compile_html = (params)=>
    fs.writeFileSync "public/#{params.platform}.#{params.extension or 'html'}", template.generate(Object.assign({development: false}, params))


  grunt.registerTask 'production', ->
    done = this.async()
    platform_compile_css()
    template_config = Object.keys(template.config_get().javascripts)
    platforms = ['standalone', 'draugiem', 'facebook', 'inbox'].filter (platform)-> template_config.indexOf(platform) >= 0
    platform_exec = (i)=>
      platform_compile_html {platform: platforms[i], template: 'game'}
      platform_compile_js platforms[i], =>
        if i >= platforms.length - 1
          return done()
        platform_exec(i + 1)
    platform_exec(0)

  grunt.registerTask 'compile', ->
    done = @async()
    files = []
    for extension in ['coffee', 'sass']
      files = files.concat(grunt.config(['watch'])[extension].files)
    compile = ->
      check = ->
        if files_all.length is 0
          return done()
        compile_file files_all.shift(), check
      compile_file files_all.shift(), check
    i = 0
    files_all = []
    files.forEach (f)->
      glob f, {}, (err, files_one)=>
        i++
        files_all = files_all.concat(files_one)
        if i is files.length
          compile()

  grunt.initConfig
    watch:
      coffee:
        files: coffee
      sass:
        files: ['client/browser/sass/*.sass']
      static:
        files: [
          'client/**/*.css'
          'client/**/*.js'
        ]
        options:
          livereload: true

  compile_file = (file, callback=->)->
    console.info "compile: #{file}"
    ext = file.split('.').pop()
    if ext is 'coffee'
      exec("#{commands.coffee} #{file}", exec_callback(callback))
    if ext is 'sass'
      exec("cd client/browser && compass compile --sourcemap sass/screen.sass -c ../../node_modules/multiplayer/client/browser/config.rb", exec_callback(callback))


  grunt.event.on 'watch', (event, file, ext)-> compile_file(file)
  grunt.registerTask('default', ['watch'])

  return {
    register_production_cordova: (files)->
      cordova_path = 'cordova'
      grunt.registerTask 'production_cordova', ->
        done = this.async()
        platform_compile_css()
        platform_compile_html {platform: 'cordova', template: 'cordova-config', extension: 'xml'}
        fs.copyFileSync 'public/cordova.xml', "#{cordova_path}/config.xml"
        fs.unlinkSync 'public/cordova.xml'
        platform_compile_html {platform: 'cordova', template: 'cordova'}
        platform_compile_js 'cordova', =>
          path = "#{cordova_path}/www"
          deleteFolderRecursive(path)
          fs.mkdirSync path
          fs.mkdirSync "#{path}/d"
          fs.mkdirSync "#{path}/d/images"
          fs.copyFileSync 'public/cordova.html', "#{path}/index.html"
          fs.unlinkSync 'public/cordova.html'
          ['c.css', 'j-cordova.js'].concat(files).forEach (f)->
            fs.copyFileSync "public/d/#{f}", "#{path}/d/#{f}"
          fs.unlinkSync 'public/d/j-cordova.js'
          done()
  }
