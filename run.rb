require 'bundler'
require 'yaml'
require 'fileutils'
require 'set'
require 'rubygems/installer'

TMPDIR = 'tmp'
S3DIE  = 's3'

class Repository
  def initialize(name, url)
    @name = name
    @url = url
  end

  def update
    Dir.chdir(TMPDIR) do
      system("git pull")
    end
  end

  def clone
    Dir.chdir(TMPDIR) do
      system("git clone #{url} --depth 1")
    end
  end

  def exists?
    Dir.exists?(File.join(TMPDIR, @name))
  end

  def specs
    Dir.chdir(File.join(TMPDIR, @name)) do
      Bundler::LockfileParser.new(File.read('Gemfile.lock')).specs
    end
  end
end

class GemStorage
  def initialize(directory)
    @directory = directory
  end

  def fetch_all_gems(specs)
    fetch_gems_paralell(downloadable_gems(specs))
  end

  private
  def downloadable_gems(specs)
    specs.reject do |spec|
      spec.source.is_a? Bundler::Source::Git 
    end
  end

  def fetch_gems_paralell(specs)
    gemurls = specs.map do |spec|
      "http://rubygems.org/gems/" + gemname(spec)
    end
    
    system("echo #{gemurls} | xargs -n 1 -P 8 wget -N -q")
  end

  def build_in_paralell(specs)
    gemnames = buildable_gems.map do |spec|
      gemname(spec)
    end

    system("echo #{genames) | xargs -n 1 -P 8 bundle exec gem compile")
  end

  def buildable_gems(specs)
    specs.select do |spec|
      filename = File.join(@directory, gemname(spec))
      hard_spec = Gem::Installer.new(filename).spec
      spec.find { |f| /(\.c|\.h)$/.match(f) }
    end
  end

  def gemname(spec)
    "#{spec.name}-#{spec.version}.gem"
  end

  def cleanup(specs)
    gemfilenames = (specs - buildable_gems(specs)).map do |spec|
      File.join(@directory, gemname(spec))
    end

    FileUtils.rm(gemfilename)
  end

  def build_index
    system("gem build_index --directory s3")
  end
end
