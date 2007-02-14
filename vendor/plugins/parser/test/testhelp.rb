require 'test/unit'
require 'yaml'
require File.join(File.dirname(__FILE__) , '..', 'lib', 'parser')

class DummyHelper
  def initialize(strings = {})
    @strings = strings
  end
  
  def template_text_for_url(url)
    url = url[1..-1] # strip leading '/'
    url = url.gsub('/','_')
    if test = @strings[url]
      test['src']
    else
      nil
    end
  end
  
  def template_url_for_asset(type,url)
    "/test_#{type}/#{url}"
  end
  
  def method_missing(sym, *args)
    arguments = args.map do |arg|
      if arg.kind_of?(Hash)
        res = []
        arg.each do |k,v|
          unless v.nil?
            res << "#{k}:#{v.inspect.gsub(/'|"/, "|")}"
          end
        end
        res.sort.join(' ')
      else
        arg.inspect.gsub(/'|"/, "|")
      end
    end
    res = "[#{sym} #{arguments.join(' ')}]"
  end
end

class Test::Unit::TestCase
  class << self
    def testfile(*files)
      @@test_strings = {}
      @@test_methods = {}
      @@test_parsers = {}
      @@test_files = []
      files.each do |file|
        file = file.to_s
        strings = {}
        test_methods = []
        YAML::load_documents( File.open( "#{file}.yml" ) ) do |doc|
          doc.each do |elem|
            test_methods << elem[0]
            strings[elem[0]] = elem[1]
          end
        end
        class_eval <<-END
          def #{file}
            @@test_strings['#{file}']
          end
        END
        @@test_strings[file] = strings.freeze
        mod_name = file.split("_").first.capitalize
        @@test_parsers[file] = Parser.parser_with_rules(eval("#{mod_name}::Rules"), eval("#{mod_name}::Tags"))
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
            class_eval <<-END
              def test_#{tf}_#{test}
                do_test(#{tf.inspect}, #{test.inspect})
              end
            END
          end
        end
      end
    end
  end
  
  def do_test(file, test)
    res = @@test_parsers[file].new_with_url("/#{test.gsub('_', '/')}", :helper=>DummyHelper.new(@@test_strings[file])).render
    if @@test_strings[file][test]['res'][0..0] == "/"
      assert_match %r{@@test_strings[file][test]['res'][1..-2]}, res
    else
      assert_equal @@test_strings[file][test]['res'], res
    end
  end
end
