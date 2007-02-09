require 'test/unit'
require 'yaml'
require File.join(File.dirname(__FILE__) , '..', 'lib', 'zafu')

class DummyHelper
  def initialize(strings)
    @strings = strings
  end
  
  def template_text_for_url(url)
    url = url[1..-1] # strip leading '/'
    url = url.gsub('/','_').to_sym
    if test = @strings[url]
      test[:in]
    else
      nil
    end
  end
end

class Test::Unit::TestCase
  class << self
    def testfile(*files)
      @@test_strings = {}
      @@test_methods = {}
      @@test_files = []
      files.each do |file|
        file = file.to_s
        strings = {}
        test_methods = []
        YAML::load_documents( File.open( "#{file}.yml" ) ) do |doc|
          doc.each do |elem|
            hash = elem[1]
            new_hash = {}
            hash.each_pair do |k,v|
              new_hash[k.to_sym] = v
            end
            test_methods << elem[0]
            strings[elem[0].to_sym] = new_hash
          end
        end
        class_eval <<-END
          def #{file}
            @@test_strings['#{file}']
          end
        END
        @@test_strings[file] = strings.freeze
        @@test_methods[file] = test_methods
        @@test_files << file
      end
    end
    def make_tests
      return unless @@test_methods
      tests = self.instance_methods.reject! {|m| !( m =~ /^test_/ )}
      @@test_files.each do |tf|
        @@test_methods[tf].each do |test|
          unless tests.include?("test_#{tf}_#{test}")
            puts "ERROR: already defined test #{tf}.yml #{test}}" if tests.include?("test_#{tf}_#{test}")
            tests << "test_#{tf}_#{test}"
            if @@test_strings[tf][test.to_sym][:out][0..0] == "/"
              # regex test
              class_eval <<-END
                def test_#{tf}_#{test}
                  assert_match %r{#{@@test_strings[tf][test.to_sym][:out][1..-2]}}m, do_test(#{tf},#{test.inspect})
                end
              END
            else
              class_eval <<-END
                def test_#{tf}_#{test}
                  assert_equal #{tf}[:#{test}][:out], do_test(#{tf},#{test.inspect})
                end
              END
            end
          end
        end
      end
    end
  end
  
  def do_test(strings, test)
    Zafu::Parser.new_with_url("/#{test.to_s.gsub('_', '/')}", DummyHelper.new(strings)).render
  end
end
