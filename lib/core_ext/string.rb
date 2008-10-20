# Avoid incompatibility with rails 'chars' version in Ruby 1.8.7
unless '1.9'.respond_to?(:force_encoding)
  String.class_eval do
    begin
      remove_method :chars
    rescue NameError
      # OK
    end
  end
end

class String
  # Parse date : return an utc date from a string and an strftime format. With the current implementation, you can only use '.', '-', ' ' or ':' to separate the different parts in the format.
  def to_utc(format, timezone=nil)
    elements = split(/(\.|\-|\/|\s|:)+/)
    format = format.split(/(\.|\-|\/|\s|:)+/)
    if elements
      hash = {}
      elements.each_index do |i|
        hash[format[i]] = elements[i]
      end
      hash['%Y'] ||= hash['%y'] ? (hash['%y'].to_i + 2000) : Time.now.year
      hash['%H'] ||= 0
      hash['%M'] ||= 0
      hash['%S'] ||= 0
      if hash['%Y'] && hash['%m'] && hash['%d']
        res = Time.utc(hash['%Y'], hash['%m'], hash['%d'], hash['%H'], hash['%M'], hash['%S'])
        timezone ? timezone.local_to_utc(res) : res
      else
        nil
      end
    else
      nil
    end
  rescue ArgumentError
    nil
  end

  # could not name this extension 'camelize'. 'camelize' is a Rails core extension to String.
  def url_name
    dup.url_name!
  end

  def url_name!
    accents = { 
      ['á',    'à','À','â','Â','ä','Ä','ã','Ã'] => 'a',
      ['é','É','è','È','ê','Ê','ë','Ë',       ] => 'e',
      ['í',    'ì','Ì','î','Î','ï','Ï'        ] => 'i',
      ['ó',    'ò','Ò','ô','Ô','ö','Ö','õ','Õ'] => 'o',
      ['ú',    'ù','Ù','û','Û','ü','Ü'        ] => 'u',
      ['œ'] => 'oe',
      ['ß'] => 'ss',
    }
    accents.each do |ac,rep|
      ac.each do |s|
        gsub!(s, rep)
      end
    end
    gsub!(/[^a-zA-Z0-9\.\-\+ ]/," ")
    replace(split.join(" "))
    gsub!(/ (.)/) { $1.upcase }
    self
  end
  
  # Convert a string of the form '1 month 4 days' to the duration in seconds.
  # Valid formats are:
  # y : Y      : year : years
  # M : month  : months
  # d : day    : days
  # h : hour   : hours
  # m : minute : minutes
  # s : second : seconds  
  def to_duration
    res = 0
    val = 0
    split(/\s+/).map {|e| e =~ /^(\d+)([a-zA-Z]+)$/ ? [$1,$2] : e }.flatten.map do |e|
      if e =~ /[0-9]/
        val = e.to_i
      else
        if e[0..1] == 'mo'
          e = 'M'
        end
        res += val * case e[0..0]
        when 'y','Y'
          31536000
        when 'M'
          2592000
        when 'd'
          86400
        when 'h'
          3600
        when 'm'
          60
        when 's'
          1
        else
          0
        end
        val = 0
      end
    end
    res
  end
  
  # return a relative path from an absolute path and a root
  def rel_path(root)
    root = root.split('/')
    path = split('/')
    i = 0
    ref  = []
    while true
      if root == []
        ref = path
        break
      elsif root[0] == path[0]
        root.shift
        path.shift
      else
        # for each root element left: '..'
        ref = root.map{'..'} + path
        break
      end
    end
    ref.join('/')
  end
  
  # return an absolute path from a relative path and a root
  def abs_path(root)
    root = root.split('/')
    path = split('/')
    while path[0] == '..'
      root.pop
      path.shift
    end
    (root + path).join('/')
  end

end