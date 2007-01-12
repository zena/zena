require 'yaml'
$password_salt = "fish zen ho"
$su_password = 'su'

class Loader < ActiveRecord::Base
  class << self
    def set_table(tbl)
      set_table_name tbl
      reset_column_information
    end
    def create(opts)
      h = {}
      opts.each_pair do |k,v|
        if :type == k
          h[:_type_] = v
        else
          h[k] = v
        end
      end
      super(h)
    end
  end
  def _type_=(t)
    self.type = t
  end
end

base_objects = {}
Dir.foreach(File.dirname(__FILE__)) do |file|
  next unless file =~ /.+\.yml$/
  YAML::load_documents( File.open( File.join(File.dirname(__FILE__), file) ) ) do |doc|
    doc.each do |elem|
      list = elem[1].map do |l|
        hash = {}
        l.each_pair do |k, v|
          hash[k.to_sym] = v
        end
        hash
      end
      tbl = elem[0].to_sym
      if base_objects[tbl]
        base_objects[tbl] += list
      else
        base_objects[tbl] = list
      end
    end
  end
end

base_objects.each_pair do |tbl, list|
  Loader.set_table(tbl.to_s)
  list.each do |record|
    if :users == tbl
      record[:password] = User.hash_password(record[:password]) if record[:password]
    elsif :items == tbl && record[:log_at] == 'today'
      record[:log_at] = Time.now
    end
    unless Loader.create(record)
      puts "could not create #{klass} #{record.inspect}"
    end
  end
end