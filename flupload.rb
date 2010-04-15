require 'rubygems'
require 'fleakr'
require 'find'

def credentials
  @credentials ||= YAML.load(File.read(File.expand_path('~/.flupload')))
rescue Errno::ENOENT
  $stderr.puts "~/.flupload doesn't exist"
  exit 1
end

Fleakr.api_key = credentials['api_key']
Fleakr.shared_secret = credentials['shared_secret']
Fleakr.auth_token = credentials['auth_token'] 

class Fluploader
  def initialize(dir)
    @dir = File.expand_path(dir)
  end
  
  def procfile
    File.join(File.dirname(__FILE__), 'processed.db')
  end
  
  def prochash
    if @prochash
      @prochash
    else
      fn = procfile
      @prochash = {}
      if File.exists?(fn)
        File.read(fn).split("\n").map{|x| x.strip}.each do |hash_maybe_with_garbage|
          hash = hash_maybe_with_garbage.gsub(/\ *#.*$/, '')
          @prochash[hash] = true
        end
      end
      @prochash
    end
  end
  
  def hash(path)
    hash = `md5 -q #{path.gsub(' ', '\ ')}`.strip
    raise "No such file: #{path}" unless hash
    hash
  end
  
  def been_processed(path)
    prochash[hash(path)]
  end
  
  def mark_processed(path)
    h = hash(path)
    File.open(procfile, 'a') {|f| f.puts("#{h} # #{File.basename(path)}")}
    prochash[h] = true
  end
  
  def with_all_files_for_upload
    Find.find(@dir) do |path|
      if path.downcase =~ /\.jpg$/ and !been_processed(path)
        if yield(path)
          mark_processed(path)
        end
      end
    end
  end
  
  def upload
    with_all_files_for_upload do |path|
      $stderr.puts "Uploading #{path}"
      Fleakr.upload(path)
      true  
    end
  end
end

if $0 == __FILE__ 
  if ARGV.first == 'auto'
    Fluploader.new('/Volumes/Untitled').upload
  elsif ARGV.first
    Fluploader.new(ARGV.first).upload
  end
end
