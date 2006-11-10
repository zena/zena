root = File.join(File.dirname(__FILE__), 'db','migrate')



require 'yaml'
base_objects = {}
Dir.foreach(root) do |file|
  next unless file =~ /.+\.yml$/
  next if file == 'base.yml'
  puts "ROOT: #{root}, FILE: #{file}"
  YAML::load_documents( File.open( File.join(root, file) ) ) do |doc|
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

trans = {}
translist = []
#base_objects[:trans].sort{|a,b| a[:key] <=> b[:key]}.each do |key|
#  trans[key[:key]] = {:id=>id, :trad=>[]}
#  translist << trans[key[:key]]
#end

base_objects[:trans_values].each do |val|
  trans[val[:keyword]] ||= {:id=>0, :trad=>[]}
  trans[val[:keyword]][:trad] << {:lang=>val[:lang], :value=> val[:value]}
end

trans_values = {}
id = 0
trans_list = trans.to_a.sort
File.open(File.join(File.dirname(__FILE__), 'trans.yml'), 'w') do |f|
  f.puts "trans:"
  trans_list.each do |key, value|
    id += 1
    value[:id] = id
    f.puts "  - id:   #{id}"
    f.puts "    key:  \"#{key.gsub('"', "'")}\""
    f.puts ""
    value[:trad].each do |h|
      trans_values[h[:lang]] ||= []
      trans_values[h[:lang]] << {:trans_id=>id, :value=>h[:value]}
    end
  end
end

id = 0
trans_values.to_a.sort.each do |lang, trads|
  puts "\n\n===================== #{lang} ================================"
  
  File.open(File.join(File.dirname(__FILE__), "#{lang}.yml"), 'w') do |f|
    f.puts "trans_values:"
    trads.each do |t|
      id += 1
      f.puts "  - id:        #{id}"
      f.puts "    trans_id:  #{t[:trans_id]}"
      f.puts "    lang:      #{lang}"
      f.puts "    value:     \"#{t[:value].gsub('"', "'")}\""
      f.puts ""
    end
  end
end
  
  
  
  
  
  