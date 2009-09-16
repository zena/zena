# FIXME: do we really need to monkey patch String ?

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