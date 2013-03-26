# encoding: utf-8
require 'test_helper'

class StringHashTest < Test::Unit::TestCase
  context 'A StringHash' do
    subject do
      StringHash[:a => 1, 'b' => '2']
    end

    should 'transform all keys to string' do
      assert_equal Hash['a' => '1', 'b' => '2'], subject
    end
    
    should 'convert to json' do
      assert_match %r{"json_class":"StringHash","data":\{"b":"2","a":"1"|"a":"1","b":"2"\}|"data":\{"b":"2","a":"1"|"a":"1","b":"2"\},"json_class":"StringHash"}, subject.to_json
    end
    
    should 'create from json' do
      obj = JSON.parse(subject.to_json)
      assert_equal StringHash, obj.class
      assert_equal obj, subject
    end
    
    should 'merge' do
      subject.merge!(:a => 4, 'c' => '3')
      assert_equal StringHash, subject.class
      assert_equal Hash['a' => '4', 'b' => '2', 'c' => '3'], subject
    end
  end # A string with accents
end