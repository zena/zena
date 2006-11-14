class Pcache < ActiveRecord::Base
  def self.cache_for(args)
    if cache = find_cache(extract_args(args))
      cache.content
    else
      nil
    end
  end
  
  def self.cache_content(content, arguments)
    args = extract_args(arguments)
    unless cache = find_cache(args)
      cache = Pcache.new(args)
    end      
    cache.content = content
    cache.save
  end
  
  def self.expire_cache(args)
    context = extract_args(args)
    find_s = []
    find_a = []
    context.each_pair do |k,v|
      k = k.to_s
      if k.gsub(/[^a-zA-Z0-9_]*/,'') != k
        # no SQL injection here !
        raise Zena::AccessViolation, "Expire cache filter before query."
      end
      find_s << "#{k}=?"
      find_a << v
    end
    caches = self.find(:all, :conditions=>[find_s.join(' AND '), find_a])
    ok = true
    caches.each do |c|
      unless c.destroy
        ok = false
      end
    end
    ok
  rescue ActiveRecord::RecordNotFound
    # ok, do nothing
  end
  
  private
  def self.extract_args(args)
    res = args.dup
    res[:visitor_groups] = res[:visitor_groups].join('.') if res[:visitor_groups]
    res[:context] = res[:context].join('.') if res[:context]
    res[:plug] = res[:plug].to_s if res[:plug]
    res
  end
  def self.find_cache(args)
    cache = self.find( :first, :conditions=>['visitor_id=? AND visitor_groups=? AND lang=? AND plug=? AND context=?',
                              args[:visitor_id], args[:visitor_groups], args[:lang], args[:plug], args[:context]      ] )
    cache
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
