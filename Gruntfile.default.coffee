fs = require('fs')
exec = require('child_process').exec
glob = require('glob')


module.exports = (grunt, template, commands)->
  grunt.loadNpmTasks('grunt-contrib-watch')
  coffee = [
    'client/*.coffee'
    'client/**/*.coffee'
    'locale/*.coffee'
  ]
  exec_callback = (callback)->
    (error, stdout, stderr)->
      if error
        console.log('exec error: ' + error)
      callback()

  grunt.registerTask 'production', ->
    done = this.async()
    exec "#{commands.uglifycss} client/browser/css/screen.css > public/d/c.css"
    template_config = Object.keys(template.config_get().javascripts)
    platforms = ['standalone', 'draugiem', 'facebook', 'inbox'].filter (platform)-> template_config.indexOf(platform) >= 0
    platforms_exec = (i)=>
      platform = platforms[i]
      fs.writeFileSync "public/#{platform}.html", template.game({platform, development: false})
      fs.writeFileSync 'all-temp.js', template.js_get(platform).map( (f)->
        if f.substr(-3) is '.js'
          return fs.readFileSync(f, 'utf8')
        return f
      ).join("\n")
      exec "#{commands.uglifyjs} --beautify \"indent-level=0\" all-temp.js -o public/d/j-#{platform}.js", =>
        exec "rm all-temp.js", =>
          i++
          if i >= platforms.length
            done()
          else
            platforms_exec(i)
    platforms_exec(0)

  grunt.registerTask 'compile', ->
    done = @async()
    files = []
    for extension in ['coffee', 'sass']
      files = files.concat(grunt.config(['watch'])[extension].files)
    j = 0
    compile = ->
      files_all.forEach (f)->
        compile_file f, ->
          j++
          if j is files_all.length
            done()
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
    ext = file.split('.').pop()
    if ext is 'coffee'
      exec("#{commands.coffee} #{file}", exec_callback(callback))
    if ext is 'sass'
      exec("cd client/browser && compass compile --sourcemap sass/screen.sass -c ../../node_modules/multiplayer/client/browser/config.rb", exec_callback(callback))


  grunt.event.on 'watch', (event, file, ext)-> compile_file(file)
  grunt.registerTask('default', ['watch'])
