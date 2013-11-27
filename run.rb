require 'bundler'
require 'yaml'
require 'fileutils'
require 'set'
require 'rubygems/installer'

def process_repo(repo_addr)
  FileUtils.mkdir_p('tmp')
  Dir.chdir('tmp') do
    puts repo_addr
    `git clone #{repo_addr} --depth 1`
  end
end

def repo_dirs
  Dir['tmp/*']
end

repos = YAML.load_file('config.yml')['repos']
repos.each { |r| process_repo(r) }
lockfiles = repo_dirs.collect do |repo_dir|
  Bundler::LockfileParser.new(File.read(File.join(repo_dir, 'Gemfile.lock')))
end

FileUtils.mkdir_p('s3/gems')
Dir.chdir('s3/gems') do
  gemnames = lockfiles.inject(Set[]) do |acc, lockfile|
    lockfile.specs.each do |spec|
      next if spec.source.is_a?(Bundler::Source::Git)

      acc << "#{spec.name}-#{spec.version}.gem"
    end
    acc
  end.to_a.map do |gemname|
    "http://rubygems.org/gems/#{gemname}"
  end

  `echo #{gemnames.join(' ')} | xargs -n 1 -P 8 wget -N -q`

  gems_to_build = Dir['*.gem'].inject([]) do |acc, gem|
    spec = Gem::Installer.new(gem).spec
    if spec.files.find { |f| /(\.c|\.h)$/.match(f) }
      acc << gem
    end
    acc
  end

  all_gems = Dir['*.gem']

  gems_to_remove = all_gems - gems_to_build

  `echo #{gems_to_build.join(' ')} | xargs -n 1 -P 8 bundle exec gem compile`
  FileUtils.rm(gems_to_remove)
end

`gem build_index --directory s3`


