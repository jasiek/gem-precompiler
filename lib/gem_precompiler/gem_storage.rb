module GemPrecompiler
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
      end.uniq do |spec|
        gemname(spec)
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
end
