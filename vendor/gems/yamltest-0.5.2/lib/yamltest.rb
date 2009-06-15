require 'test/unit'
require 'yaml'

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module Yamltest
  VERSION = '0.5.2'
  module Helper
    def self.included(obj)
      obj.extend Yamltest::ClassMethods
    end
  end
  
  module ClassMethods
    
    # build an array of file_name, file_path, options
    def file_list(caller_path, opts)
      directories = opts[:directories] || [opts[:directory] || :default]
      
      if files = opts[:files]
        files.map!{|f| f.to_s}
      end
      
      directories = directories.map do |dir|
        if dir == :default
          if caller_path.split('/').last =~ /^(.*)_test.rb/ || caller_path.split('/').last =~ /^test_(.*).rb/
            directories = [File.join(File.dirname(caller_path), $1)]
          else
            puts "Bad file name for yaml_tests '#{caller_path}'. Should be 'xxx_test.rb' or 'test_xxx.rb'. Trying parent directory."
            directories = [File.dirname(caller_path)]
          end
        else
          # relative to caller
          Dir[File.join(File.dirname(caller_path),dir)]
        end
      end.flatten

      file_list = []
      
      directories.each do |dir|
        Dir.foreach(dir) do |f|
          next unless f =~ /^([\w_-]+).yml/
          next if files && !files.include?($1)
          file_list << [$1, File.join(dir, "#{$1}.yml"), opts[$1] || opts[$1.to_sym] || {}]
        end
      end
      
      file_list
    end
    
    
    # Setup yaml testing.
    # usage:
    # class SuperTest < Test::Unit::TestCase
    #   yamltest
    #
    # or to define custom search directories for tests definitions
    # class SuperTest < Test::Unit::TestCase
    #   yamltest :directories => ["sub/**", "/absolute/location"]
    #
    # to use only some files:
    # class SuperTest < Test::Unit::TestCase
    #   yamltest :files => ["one", "two"]
    #
    # to pass parameters during testing of a specific file:
    # class SuperTest < Test::Unit::TestCase
    #   yamltest :options => {:latex => {:module => Latex}}
    #
    def yamltest(opts = {})
      # We need to do a class_eval so that the class variables 'test_strings, test_methods, ...' are scoped
      # in the final class and are not global to all tests using the YamlTest helper.
      
      class_eval %Q{
        @@test_strings = {}
        @@test_methods = {}
        @@test_options = {}
        @@test_files = []
        @@file_list  = file_list(#{caller[0].inspect}, #{opts.inspect})
        
        @@file_list.each do |file_name, file_path, opts|
          strings = {}
          test_methods = []
          begin
            YAML::load_documents( File.open( file_path ) ) do |doc|
              doc.each do |elem|
                test_methods << elem[0]
                strings[elem[0]] = elem[1]
              end
            end
          rescue ArgumentError => err
            puts "Error while loading test file \#{file_path}"
            raise err
          end
          class_eval "
            def \#{file_name}
              @@test_strings['\#{file_name}']
            end
          "
          @@test_strings[file_name] = strings.freeze
          @@test_methods[file_name] = test_methods
          @@test_files << file_name
        end
        
        # Override this in your test class
        def yt_parse(key, source, context)
          source
        end
        
        def yt_do_test(file, test, context = yt_get('context',file,test))
          @@test_strings[file][test].keys.each do |key|
            next if ['src', 'context'].include?(key)
            yt_assert yt_get(key,file,test), yt_parse(key, yt_get('src',file,test), context)
          end
        end
        
        protected
          def yt_assert(test_res, res)
            if test_res.kind_of?(String) && test_res[0..1] == '!/'
              assert_no_match %r{\#{test_res[2..-2]}}m, res
            elsif test_res.kind_of?(String) && test_res[0..0] == '/'
              assert_match %r{\#{test_res[1..-2]}}m, res
            else
              assert_equal test_res, res
            end
          end
          
          def yt_get(key, file, test)
            case key
            when 'context', :context
              context = @@test_strings[file][test]['context'] || {}
              default_context = (@@test_strings[file]['default'] || {})['context'] || {}
              context = default_context.merge(context)
            when 'src'
              @@test_strings[file][test]['src'] #{opts[:src_from_title] != false ? "|| (test.gsub('_',' '))" : ''}
            else
              @@test_strings[file][test][key.to_s]
            end
          end
      }
    end
    
    def yt_make
      class_eval %q{
        return unless @@test_methods
        tests = self.instance_methods.reject! {|m| !( m =~ /^test_/ )}
        @@test_files.each do |tf|
          @@test_methods[tf].each do |test|
            unless tests.include?("test_#{tf}_#{test}")
              tests << "test_#{tf}_#{test}"
              class_eval <<-END
                def test_#{tf}_#{test}
                  yt_do_test(#{tf.inspect}, #{test.inspect})
                end
              END
            end
          end
        end
      }
    end
  end
end

Test::Unit::TestCase.send :include, Yamltest::Helper