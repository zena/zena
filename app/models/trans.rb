class Trans < ActiveRecord::Base
  attr_accessor :value, :lang
  has_many :trans_values
  
  class << self
    def [](keyword)
      key = Trans.find_by_key(keyword)
      unless key
        key = Trans.create(:key=>keyword)
      end
      key
    end
  end
  
  def [](la)
    if la.kind_of?(Symbol)
      super
    else
      val = self.trans_values.find(:first,
                    :select=>"*, (lang = '#{la.gsub(/[^\w]/,'')}') as lang_ok, (lang = '#{ZENA_ENV[:default_lang]}') as def_lang",
                    :order=>"lang_ok DESC, def_lang DESC")
      val ? val[:value] : self[:key]
    end
  end
  
  def []=(la,value)
    val = self.trans_values.find_by_lang(la) || TransValue.new(:lang=>la, :trans_id=>self[:id])
    val[:value] = value
    val.save
  end
  
  def size
    trans_values.size
  end
end
