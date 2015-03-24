fs = require 'fs'
module.exports.suppe = (grunt, opts = {}) ->

  {bower_dir, closure_lib_dir, coffee_files, app_compiled_output_path, deps_path, deps_prefix, var_dir, src_dir, app_namespace, watch_dirs, overridden_config, closure_libs, externs} = opts

  bower_dir ?= 'bower_components'
  closure_lib_dir ?= bower_dir + '/closure-library'
  var_dir ?= 'var'
  src_dir ?= 'cs'
  app_namespace ?= 'app.start'
  overridden_config ?= {}
  closure_libs ?= ["#{var_dir}/#{bower_dir}/werkzeug/**/*.js"]
  closure_libs.push "#{var_dir}/#{src_dir}/**/*.js"
  sass_dir = "dj/static/styles"

  app_dirs = [
    closure_lib_dir
    "#{var_dir}/#{src_dir}"
  ]

  bower_var = "#{var_dir}/#{bower_dir}"
  if fs.existsSync bower_var
    app_dirs.push bower_var
  coffee_files ?= [
    "#{src_dir}/**/*.coffee"
    bower_dir + '/werkzeug/**/*.coffee'
  ]

  watch_dirs ?= []
  watch_dirs = watch_dirs.concat "#{src_dir}/**/", "#{var_dir}/#{src_dir}/**/", "#{sass_dir}/**/"

  app_compiled_output_path ?= 'dj/static/js/app.js'

  deps_path ?= "#{var_dir}/#{src_dir}/deps.js"

  # from closure base.js dir to app root dir
  deps_prefix ?= '../../../../static/js/'

  config =

    clean:
      all:
        options:
          force: true
        src: [
          "#{var_dir}/#{src_dir}/**/*.js"
        ]

    coffee:
      all:
        options:
          bare: true
        files: [
          expand: true
          src: coffee_files
          dest: var_dir + '/'
          ext: '.js'
        ]

    coffee2closure:
      all:
        files: [
          expand: true
          src: closure_libs
          ext: '.js'
        ]

    esteDeps:
      all:
        options:
          depsWriterPath: closure_lib_dir + '/closure/bin/build/depswriter.py'
          outputFile: deps_path
          prefix: deps_prefix
          root: app_dirs

    zuckrig:
      all:
        options:
          filter: (file) -> not /_test.js$/.test(file)
        files: [
          expand: true
          src: closure_libs
          ext: '.js'
        ]

    esteBuilder:
      options:
        closureBuilderPath: closure_lib_dir + '/closure/bin/build/closurebuilder.py'
        compilerPath: bower_dir + '/closure-compiler/compiler.jar'
        # needs Java 1.7+, see http://goo.gl/iS3o6
        fastCompilation: true
        root: '<%= esteDeps.all.options.root %>'
        depsPath: '<%= esteDeps.all.options.outputFile %>'
        compilerFlags: if grunt.option('stage') == 'debug' then [
          '--output_wrapper="(function(){%output%})();"'
          '--compilation_level="ADVANCED_OPTIMIZATIONS"'
          '--warning_level="VERBOSE"'
          '--define=goog.DEBUG=true'
          '--debug=true'
          '--formatting="PRETTY_PRINT"'
        ]
        else [
            '--output_wrapper="(function(){%output%})();"'
            '--compilation_level="ADVANCED_OPTIMIZATIONS"'
            '--warning_level="VERBOSE"'
            '--define=goog.DEBUG=false'
          ]

      all:
        options:
          namespace: app_namespace
          outputFilePath: app_compiled_output_path

    esteUnitTests:
      options:
        basePath: closure_lib_dir + '/closure/goog/base.js'
      all:
        options:
          depsPath: '<%= esteDeps.all.options.outputFile %>'
          prefix: '<%= esteDeps.all.options.prefix %>'
        src: [
          "#{var_dir}/#{src_dir}/**/*_test.js"
        ]

    sass:
      all:
        files:
          [{
            expand: true
            cwd: sass_dir
            src: ['*.sass']
            dest: "#{sass_dir}/dist"
            ext: '.css'
          }]
      dist:
        options:
          sourcemap: 'none'

    esteWatch:
      options:
        dirs: watch_dirs

      coffee: (filepath) ->
        config = [
          expand: true
          src: filepath
          dest: var_dir + '/'
          ext: '.js'
        ]
        grunt.config ['coffee', 'all', 'files'], config
        grunt.config ['zuckrig', 'all', 'files'], config
        grunt.config ['coffee2closure', 'all', 'files'], config
        ['coffee', 'zuckrig', 'coffee2closure']

      js: (filepath) ->
        grunt.config ['esteDeps', 'all', 'src'], filepath
        grunt.config ['esteUnitTests', 'all', 'src'], filepath
        ['esteDeps', 'esteUnitTests']

      sass: ->
        ['sass']

    coffeelint:
      options:
        no_backticks:
          level: 'ignore'
        max_line_length:
          level: 'ignore'
        line_endings:
          value: 'unix'
          level: 'error'
        no_empty_param_list:
          level: 'warn'
      all:
        files: [
          expand: true
          src: coffee_files
          ext: '.js'
        ]

  # allows to use external libraries in closure
  if externs?
    for extern in externs
      config.esteBuilder.options.compilerFlags.push "--externs=#{extern}"

  config[k] = v for k, v of overridden_config
  grunt.initConfig config

  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-este'
  grunt.loadNpmTasks 'grunt-este-watch'
  grunt.loadNpmTasks 'grunt-zuckrig-closure'

  grunt.registerTask 'build', 'Build app.', ->
    tasks = [
      "clean"
      "sass"
      "coffee"
      'zuckrig'
      "coffee2closure"
      "coffeelint"
      "esteDeps"
      "esteUnitTests"
      "esteBuilder"
    ]
    grunt.task.run tasks

  grunt.registerTask 'run', 'Build app and run watchers.', ->
    tasks = [
      "clean"
      "sass"
      "coffee"
      'zuckrig'
      "coffee2closure"
      "coffeelint"
      "esteDeps"
      "esteUnitTests"
      "esteWatch"
    ]
    grunt.task.run tasks

  grunt.registerTask 'default', 'run'

  grunt.registerTask 'test', 'build'
