$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name     = "git-pulls"
  s.version  = "1.0.0"
  s.date     = Time.now.strftime('%Y-%m-%d')
  s.summary  = "facilitates github pull requests"
  s.homepage = "http://github.com/schacon/git-pulls"
  s.email    = "adrien.giboire@gmail.com"
  s.authors  = ["Adrien Giboire", "Scott Chacon"]

  s.files    = %w( LICENSE )
  s.files    += Dir.glob("lib/**/*")
  s.files    += Dir.glob("bin/**/*")

  s.executables = %w( git-pulls )
  s.description = "git-pulls facilitates github pull requests."

  s.add_runtime_dependency 'launchy'
  s.add_runtime_dependency 'octokit'
  s.add_runtime_dependency 'git'
  s.add_runtime_dependency 'awesome_print'
end
