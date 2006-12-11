class TransHash < Hash
  def initialize(id, keyword)
    self[:id] = id
    self[:key] = keyword
  end
  def [](la)
    super || begin
      val = TransValue.find(:first,
                      :select=>"*, (lang = '#{la.gsub(/[^\w]/,'')}') as lang_ok, (lang = '#{ZENA_ENV[:default_lang]}') as def_lang",
                      :conditions=>"key_id = #{super(:id)}",
                      :order=>"lang_ok DESC, def_lang DESC")
      self[la] = val ? val[:value] : super(:key)
    end
  end
end

class TransKey < ActiveRecord::Base
  attr_accessor :lang, :value
  before_save :check_value
  after_save :save_value
  has_many :trans_values, :foreign_key=>'key_id'
  
  @@key = {}
  class << self
    def translate(keyword)
      key = TransKey.find_by_key(keyword)
      unless key
        key = TransKey.create(:key=>keyword)
      end
      key
    end
    def [](keyword)
      @@key[keyword] || begin
        key = TransKey.find_by_key(keyword) || TransKey.create(:key=>keyword)
        @@key[keyword] = TransHash.new(key[:id], keyword)
      end
    end
    def clear
      @@key = {}
    end
  end
  
  def into(la)
    val = self.trans_values.find(:first,
                    :select=>"*, (lang = '#{la.gsub(/[^\w]/,'')}') as lang_ok, (lang = '#{ZENA_ENV[:default_lang]}') as def_lang",
                    :order=>"lang_ok DESC, def_lang DESC")
    val = val ? val[:value] : self[:key]
  end
  
  def set(la,value)
    val = self.trans_values.find_by_lang(la) || TransValue.new(:lang=>la, :key_id=>self[:id])
    val[:value] = value
    val.save
    TransKey.clear
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
