require 'rubygems'
require 'tzinfo'
require 'test/unit'
require 'fileutils'
require File.join(File.dirname(__FILE__), '../../lib/zena/core_ext/string')
require File.join(File.dirname(__FILE__), '../../lib/zena/core_ext/fixnum')
require File.join(File.dirname(__FILE__), '../../lib/zena/core_ext/dir')

class StringExtTest < Test::Unit::TestCase
  def test_abs_rel_path
    {
      'a/b/c/d' => 'd',
      'a/x'     => '../../x',
      'y/z'     => '../../../y/z',
      'a/b/d'   => '../d',
      'a/b/c'   => '',
      }.each do |orig, test_rel|
        rel = orig.rel_path('a/b/c')
        assert_equal rel, test_rel, "'#{orig}' should become the relative path '#{test_rel}'"
        abs = rel.abs_path('a/b/c')
        assert_equal rel, test_rel, "'#{rel}' should become the absolute path '#{orig}'"
    end

    {
      'a/b/c/d' => 'a/b/c/d',
      'a/x'     => 'a/x',
      }.each do |orig, test_rel|
        rel = orig.rel_path('')
        assert_equal rel, test_rel, "'#{orig}' should become the relative path '#{test_rel}'"
        abs = rel.abs_path('')
        assert_equal rel, test_rel, "'#{rel}' should become the absolute path '#{orig}'"
    end

    assert_equal "/a/b/c", ''.abs_path('/a/b/c')
  end
end

class DirExtTest < Test::Unit::TestCase
  def test_empty?
    name = 'asldkf9032oi09sdflk'
    FileUtils.rmtree(name)
    FileUtils.mkpath(name)
    assert File.exist?(name) && Dir.empty?(name)
    File.open(File.join(name,'hello.txt'), 'wb') {|f| f.puts "hello" }
    assert !Dir.empty?(name)
    FileUtils.rmtree(name)
  end
end