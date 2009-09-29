#!/usr/bin/env ruby
require "yaml"

buffer = []
STDIN.each_line { |l| buffer << l }

def yaml_to_context hash, indent=0
  indent1 = '  '*indent
  indent2 = '  '*(indent+1)
  hash.each_pair do |context,shoulds|
    puts indent1+"context \"#{context}\" do"
    puts    
    shoulds.each do |should|
      yaml_to_context( should, indent+1 ) and next if should.is_a?( Hash )
      puts indent2+"should_eventually \"#{should.gsub(/^should +/,'')}\" do"
      puts indent2+"end"
      puts
    end
    puts indent1+"end"
  end 
end

hash = YAML.load( buffer.join("\n") )
# puts hash.inspect
yaml_to_context hash
