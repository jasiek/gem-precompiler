module GemPrecompiler
  class Repository
    def initialize(name, url, tmpdir)
      @name = name
      @url = url
      @tmpdir = tmpdir
    end

    def sync
      if exists?
        update
      else
        clone
      end
    end

    def specs
      @specs ||= Bundler::LockfileParser.new(File.read(File.join(@tmpdir, @name, 'Gemfile.lock'))).specs
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
      Dir.exists?(File.join(@tmpdir, @name))
    end

    def in_local_copy(&blk)
      chdir(@dir, &blk)
    end

    def in_tmp_dir(&blk)
      chdir(nil, &blk)
    end

    def chdir(dir, &blk)
      if dir
        Dir.chdir(File.join(@tmpdir, dir, &blk))
      else
        Dir.chdir(@tmpdir, &blk)
      end
    end
  end
end
