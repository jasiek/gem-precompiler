require 'bundler'
Bundler.require
require_relative 'lib/gem_precompiler'

directory(TMP_DIR = 'tmp')
directory(S3_DIR = 's3/gems')

task :clean do
   rm_rf([TMP_DIR, S3_DIR])
end

task :build => [TMP_DIR, S3_DIR] do
  config = YAML.load_file('config.yml')['repos']
  repos = config.collect do |name, url|
    GemPrecompiler::Repository.new(name, url, TMP_DIR)
  end
  repos.each(&:sync)
  
  storage = GemPrecompiler::GemStorage.new(S3_DIR)
  repos.each do |repo|
    storage.fetch_all_gems(repo.specs)
    storage.build_all_gems(repo.specs)
    storage.cleanup(repo.specs)
  end
  storage.build_index
end

task :upload do
  sh "s3_website push --site s3"
end

task :default => [:build, :upload]

