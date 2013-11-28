require 'bundler'
require 'yaml'
require 'fileutils'
require 'rubygems/installer'

TMPDIR = 'tmp'
S3DIE  = 's3'

class Repository
  def initialize(name, url)
    @name = name
    @url = url
  end

  def sync
    if exists?
      update
    else
      clone
    end
  end

  def specs
    @specs ||= Bundler::LockfileParser.new(File.read(File.join(TMPDIR, @name, 'Gemfile.lock'))).specs
  end
  
  private
  def update
    in_local_copy do
      system("git pull")
    end
  end

  def clone
    in_tmp_dir do
      system("git clone #{@url} --depth 1 #{@name}")
    end
  end

  def exists?
    Dir.exists?(File.join(TMPDIR, @name))
  end

  def in_local_copy(&blk)
    chdir(@dir, &blk)
  end

  def in_tmp_dir(&blk)
    chdir(nil, &blk)
  end

  def chdir(dir, &blk)
    if dir
      Dir.chdir(File.join(TMPDIR, dir, &blk))
    else
      Dir.chdir(TMPDIR, &blk)
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

  def build_all_gems(specs)
    build_in_paralell(downloadable_gems(specs))
  end

  def cleanup(specs)
    gemfilenames = (downloadable_gems(specs) - buildable_gems(specs)).map do |spec|
      File.join(@directory, gemname(spec))
    end

    FileUtils.rm_f(gemfilenames)
  end

  def build_index
    system("gem generate_index --directory s3")
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
    
    in_directory do
      system("echo #{gemurls.join(' ')} | xargs -n 1 -P 8 wget -N -q")
    end
  end

  def build_in_paralell(specs)
    gemnames = buildable_gems(specs).map do |spec|
      gemname(spec)
    end

    in_directory do
      system("echo #{gemnames.join(' ')} | xargs -n 1 -P 8 bundle exec gem compile")
    end
  end

  def buildable_gems(specs)
    downloadable_gems(specs).select do |spec|
      filename = File.join(@directory, gemname(spec))
      next false unless File.exists?(filename)

      hard_spec = Gem::Installer.new(filename).spec
      hard_spec.files.find { |f| /(\.c|\.h)$/.match(f) }
    end
  end

  def gemname(spec)
    "#{spec.name}-#{spec.version}.gem"
  end

  def in_directory(&blk)
    Dir.chdir(@directory, &blk)
  end
end

config = YAML.load_file('config.yml')['repos']
repos = config.collect do |name, url|
  Repository.new(name, url)
end
repos.each(&:sync)

storage = GemStorage.new('s3/gems')
repos.each do |repo|
  storage.fetch_all_gems(repo.specs)
  storage.build_all_gems(repo.specs)
  storage.cleanup(repo.specs)
end
storage.build_index

