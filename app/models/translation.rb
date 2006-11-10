# Rails error messages to be translated TODO : activerecord/validations.rb

class Translation < ActiveRecord::Base
  after_save :updateHash
  
  def Translation.makeHash
    phrases = Translation.find(:all, :order=>'keyword')
    tstrings = {}
    last_key = ''
    translation = {}
    phrases.each do |p|
      if p.keyword != last_key
        tstrings[last_key.to_s] = translation
        translation = {}
        last_key = p.keyword
      end
      translation[p.lang] = p.value
    end    
    tstrings[last_key] = translation
    tstrings.freeze
    tstrings
  end
  private
  def updateHash
    $tstrings = Translation.makeHash
  end
end
