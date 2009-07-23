# http://sneaq.net/textmate-wtf
$:.reject! { |e| e.include? 'TextMate' }

require 'rubygems'
require 'stringio'
require 'test/unit'
require File.dirname(__FILE__) + '/../lib/yamltest'
