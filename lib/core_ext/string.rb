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
        res = Time.gm(hash['%Y'], hash['%m'], hash['%d'], hash['%H'], hash['%M'], hash['%S'])
        timezone ? timezone.unadjust(res) : res
      else
        nil
      end
    else
      nil
    end
  end

  def limit(num)
    if length > num && num > 10
      self[0..(num-4)] + "..."
    elsif length > num
      self[0..(num-1)]
    else
      self
    end
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
    gsub!(/[^a-zA-Z0-9\.\-\* ]/," ")
    replace(split.join(" "))
    gsub!(/ (.)/) { $1.upcase }
    self
  end

end
