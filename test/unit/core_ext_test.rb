# encoding: utf-8
require 'test_helper'

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

  context 'A string with accents' do
    subject do
      "aïl en août"
    end

    should 'remove accents on to_filename' do
      assert_equal 'a%C3%AFl en ao%C3%BBt', subject.to_filename
    end

    should 'recover original name on from_filename' do
      assert_equal subject, String.from_filename(subject.to_filename)
    end

    should 'transform on urlencode' do
      assert_equal 'a%C3%AFl%20en%20ao%C3%BBt', subject.urlencode
    end
  end # A string with accents

  context 'A long string' do
    subject do
      "12345678901234567890"
    end

    should 'limit size on limit' do
      assert_equal '123456789012345…', subject.limit(15)
    end

    should 'append readmore argument on limit' do
      assert_equal '123456789012345 <a href="">read more</a>', subject.limit(15, ' <a href="">read more</a>')
    end

    should 'not append readmore argument if limit is not reached' do
      assert_equal '12345678901234567890', subject.limit(25, ' <a href="">read more</a>')
    end

    should 'not raise on negative limit' do
      assert_equal ' <a href="">read more</a>', subject.limit(-35, ' <a href="">read more</a>')
    end
  end # A string with accents
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