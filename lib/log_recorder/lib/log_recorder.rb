# on mac os x, install rb-mysql port (port install rb-mysql)
# on debian install ?????
require 'rubygems'
require 'mysql' # to have Mysql class
require 'yaml'
require 'date'

# Use this custom format (we do not record the logname or user):
# LogFormat "%v %h %{%Y-%m-%d %H:%M:%S %z}t %T %>s %b %m \"%U\" \"%{Referer}i\" \"%{User-agent}i\" \"%r\"" zenaLog
# 
class LogRecorder
  class FormatError < Exception; end
  
  MONTH_MAP = {
   'Jan' => 1,
   'Feb' => 2,
   'Mar' => 3,
   'Apr' => 4,
   'May' => 5,
   'Jun' => 6,
   'Jul' => 7,
   'Aug' => 8,
   'Sep' => 9,
   'Oct' => 10,
   'Nov' => 11,
   'Dec' => 12
  }
  
  def initialize(vhost_name, config)
    @vhost_name = vhost_name
    @mysql = Mysql.init
    @mysql.real_connect(config['host'], config['username'], config['password'], config['database'], config['port'], config['socket'])
    config['password'] = nil # do not keep in memory
  end
  
  # Insert a record in the form 
  # "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\""
  # %h %t %T %>s %b %m %v %h \"%U\" \"%{Referer}i\" \"%{User-agent}i\" \"%r\"
  # 127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326 "http://www.example.com/start.html" "Mozilla/4.08 [en] (Win98; I ;Nav)"
  def insert_combined_record(rec)
    remote_host,duno,user,date,request,status,size,referer,agent = parse_record(rec)
    
    date = parse_date(date)
    verb, path = parse_path(request)
    lang, zip, mode, format = get_parameters(path)
    
    puts [remote_host,duno,user,date,[lang,zip,mode,format],status,size,referer,agent].inspect
  end
  
  def parse_record(rec)
    # %v %h %{%Y-%m-%d %H:%M:%S %z}t %T %>s %b %m \"%U\" \"%{Referer}i\" \"%{User-agent}i\" \"%r\"
    # FIX ...
    if rec =~ /\A([\d\.]+) (\S+) (\S+) \[([\w:\/]+\s[+\-]\d{4})\] "([^"]+)" (\d{3}) (\d+) "([^"]+)" "([^"]+)"/
      return $~.to_a[1..-1]
    else
      # bad
      raise FormatError.new("could not parse record from #{rec.inspect}")
    end
  end
  
  def parse_date(eng_date)
    if eng_date =~ /(\d+)\/(\w+)\/(\d+):(\d+):(\d+):(\d+) ([+-])(\d{2})(\d{2})/
      match,d,m,y,h,min,s,ds,delta_h,delta_m = *($~.to_a)
      m    = MONTH_MAP[m]
      time = Time.utc(y.to_i,m,d.to_i,h.to_i,min.to_i,s.to_i)
      time += (ds == '+' ? 1 : -1) * (delta_h.to_i * 3600 + delta_m.to_i * 60)
    else
      # bad
      raise FormatError.new("could not parse date from #{eng_date.inspect}")
    end
    return time.strftime("%Y-%m-%d %H:%M:%S")
  end
  
  def parse_path(request)
    if request =~ /\A(\w+) ([^ ]+)/
      return [$1, $2]
    else
      # bad..
      raise FormatError.new("could not parse path from #{request.inspect}")
    end
  end
  
  
  def test
    parts = parse_record('127.0.0.1 - frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326 "http://www.example.com/start.html" "Mozilla/4.08 [en] (Win98; I ;Nav)"')
    puts parts.inspect
    puts parse_date("10/Oct/2000:13:55:36 +0100")
    puts parse_date("10/Oct/2000:13:55:36 -0100")
    puts parse_path("GET /apache_pb.gif HTTP/1.0")
    puts get_site_id("test.host").inspect
    puts find_zip_by_path("projects/cleanWater")
    insert_combined_record('213.3.85.165 - - [29/Feb/2008:11:34:22 +0100] "GET /en/image133_tiny.jpg HTTP/1.1" 200 4039 "http://zenadmin.org/en" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; fr) AppleWebKit/419.3 (KHTML, like Gecko) Safari/419.3"')
    insert_combined_record('213.3.85.165 - - [29/Feb/2008:11:38:09 +0100] "GET /fr/projects/cleanWater.html HTTP/1.1" 200 4760 "http://zenadmin.org/en" "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; fr) AppleWebKit/419.3 (KHTML, like Gecko) Safari/419.3"')
  end
  private
    def get_site_id(vhost_name)
      res = @mysql.query("SELECT id FROM sites WHERE host = '#{@mysql.escape_string(@vhost_name)}'")
      if row = res.fetch_row
        @site_id = row[0].to_i
      end
      unless @site_id
        # site_id not found:
        puts "could not find site_id !"
        #  1. print/log an error
        #  2. save logs to file
      end
      return @site_id
    end
    
    # Return lang, node_zip, mode, format. If node_id is null ==> admin page / controller page
    def get_parameters(path_str)
      path = path_str.split('/')[1..-1]
      if path[0] =~ /\A\w\w\Z/
        lang = path[0]
      end
      if path.last =~ /\A(([a-zA-Z]+)([0-9]+)|([a-zA-Z0-9\-\*]+))(_[a-z]+|)(\..+|)\Z/
        zip    = $3
        name   = $4
        mode   = $5 == '' ? nil : $5[1..-1]
        format = $6 == '' ? ''  : $6[1..-1]
        if name =~ /^\d+$/
          zip = name
        elsif name
          basepath = (path[0..-2] + [name]).join('/')
          zip   = find_zip_by_path(basepath)
        end
      end
      return [lang, zip, mode, format]
    end
    
    def find_zip_by_path(path)
      res = @mysql.query("SELECT zip FROM nodes WHERE site_id = '#{@site_id}' AND fullpath = '#{@mysql.escape_string(path)}'")
      if row = res.fetch_row
        return row[0].to_i
      end
      return nil
    end
end