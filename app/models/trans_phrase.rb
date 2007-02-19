class TransHash < Hash
  def initialize(id, keyword)
    self[:id] = id
    self[:phrase] = keyword
  end
  def [](la)
    super || begin
      val = TransValue.find(:first,
                      :select=>"*, (lang = '#{la.gsub(/[^\w]/,'')}') as lang_ok, (lang = '#{ZENA_ENV[:default_lang]}') as def_lang",
                      :conditions=>"phrase_id = #{super(:id)}",
                      :order=>"lang_ok DESC, def_lang DESC")
      self[la] = val ? val[:value] : super(:phrase)
    end
  end
end

class TransPhrase < ActiveRecord::Base
  attr_accessor :lang, :value
  before_save :check_value
  after_save :save_value
  has_many :trans_values, :foreign_key=>'phrase_id', :dependent=>:destroy
  
  @@key = {}
  class << self
    def translate(keyword)
      return '' unless keyword
      key = TransPhrase.find_by_phrase(keyword)
      unless key
        key = TransPhrase.create(:phrase=>keyword)
      end
      key
    end
    def [](keyword)
      return '' unless keyword
      @@key[keyword] || begin
        key = TransPhrase.find_by_phrase(keyword) || TransPhrase.create(:phrase=>keyword)
        @@key[keyword] = TransHash.new(key[:id], keyword)
      end
    end
    def clear
      @@key = {}
    end
  end
  
  def into(la)
    if self[:lang] == la && self[:value]
      self[:value] 
    else
      val = self.trans_values.find(:first,
                      :select=>"*, (lang = '#{la.gsub(/[^\w]/,'')}') as lang_ok, (lang = '#{ZENA_ENV[:default_lang]}') as def_lang",
                      :order=>"lang_ok DESC, def_lang DESC")
      val = val ? val[:value] : self[:phrase]
    end
  end
  
  def set(la,value)
    val = self.trans_values.find_by_lang(la) || TransValue.new(:lang=>la, :phrase_id=>self[:id])
    val[:value] = value
    val.save
    TransPhrase.clear
  end
  
  # TODO: test
  def id_for(la)
    if val = self.trans_values.find_by_lang(la)
      val[:id]
    else
      nil
    end
  end
  
  def value
    return nil unless @lang || @value
    @value || into(@lang)
  end
  
  def size
    trans_values.size
  end
  
  private
  def check_value
    unless (@lang && @value) || (!@value)
      errors.add('lang', 'not set')
      false
    else
      true
    end
  end
  def save_value
    return true unless @value
    set(@lang, @value)
  end
end
