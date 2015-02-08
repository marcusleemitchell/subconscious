require 'redis'
require 'digest'

class Subconscious

  SHOWDIR             = "/Volumes/DARWIN/Television"
  LANGUAGE            = "en"
  SUBTITLE_EXTENSION  = "srt"
  MOVIE_EXTENSIONS    = %w(mkv avi mpeg mp4)
  MOVIE_EXT_IGNORE    = %w(nfo srr nzb sfv jpg srs par2 xml)
  REDIS_DUMPFILE      = "#{Dir.pwd}/subconscious.json"

  def initialize(args)
    @force_dir = args[0] || nil
  end

  def run
    # load the redis data if available
    get_redis_connection
    load_redis_dump

    # find all shows
    shows.each do |show|
      # create a hash from file basename
      key = md5_filename(file_basename(show))
      unless @redis.exists key
        destination_path = File.dirname(show).gsub(/ /, '\ ')
        begin
          san_show_name = file_name(show).gsub(/ /,"_")
          p san_show_name
          san_show_name_ext = san_show_name + "." + sanitized_extension(show)
          `cd #{destination_path} ; subliminal -q -l en -- #{san_show_name_ext}`
          `cd #{destination_path} ; mv #{san_show_name}.en.srt #{file_name(show).gsub(/ /, '\ ')}.en.srt`
          @redis.set(key, Time.now)
        rescue => exception
          p exception
        end
      else
        p "Skipping #{file_basename(show)} as it's already been indexed"
      end
    end
    dump_redis
  end

  private

  def shows
    base_dir = !@force_dir.nil? ? "#{@force_dir}/**/*" : "#{SHOWDIR}/**/*"
    p "Hitting #{base_dir}"
    [].tap do |shows|
      Dir.glob(base_dir).map{ |file|
        next unless MOVIE_EXTENSIONS.include?(sanitized_extension(file))
        shows << file
      }; nil
    end
  end

  def get_redis_connection
    @redis ||= Redis.new
  end

  private

  def load_redis_dump # load
    `cat #{REDIS_DUMPFILE} | redis-load` if File.exists? REDIS_DUMPFILE
  end

  def dump_redis # save
    `redis-dump > #{REDIS_DUMPFILE}`
  end

  def file_basename(file) # this will be what we search for
    File.basename(file)
  end

  def file_name(file) # di
    element_count = file_basename(file).split(".").count
    if element_count == 2
      file_basename(file).split(".").first
    else
      file_basename(file).split(".").take(element_count-1).join(".")
    end
  end

  def sanitized_extension(file) # used to find eligable files
    File.extname(file).split(".").last
  end

  def md5_filename(filename) # used as the redis key
    Digest::MD5.hexdigest(filename)
  end

end

Subconscious.new(ARGV).run