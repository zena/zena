class FormSeizure < ActiveRecord::Base
  has_many :form_lines, :foreign_key => 'seizure_id'
  belongs_to :form, :foreign_key => 'form_id'
  belongs_to :user, :foreign_key=>'user_id'
  
  class << self
    def find_seizures(form_id, filter, visitor_groups=[1])
      # It could be possible to use multiple filters : here is an example with 2 (look at slines2):
      # SELECT seizures.* FROM form_seizures AS seizures, form_lines AS slines, 
      # form_lines AS slines2, items AS forms WHERE forms.id = seizures.form_id 
      # AND seizures.id = slines.seizure_id AND seizures.id = slines2.seizure_id 
      # AND forms.id = 32 AND forms.dgroup_id IN (1,3) AND (slines.key='animal'
      # AND slines.value='dog' AND slines2.key='year' AND slines2.value='2006') GROUP BY seizures.id
      
      if filter
        # filter : 'animal=dog'
        # FIXME [SECURITY] is there any risk here ?
        if filter.gsub(/['; ]/,'') =~ /([^<>=!]*)(<=|>=|!=|=|>|<)(.*)/
          filter = "slines.key='#{$1}' AND slines.value#{$2}'#{$3}'"
        else
          # error in filter definition. Just ignore
          "1"
        end
      else
        filter = "1"
      end
      seiz = self.find_by_sql(["SELECT seizures.* FROM form_seizures AS seizures, form_lines AS slines, items AS forms WHERE \
        forms.id = seizures.form_id AND seizures.id = slines.seizure_id AND forms.id = ? AND forms.dgroup_id IN (#{visitor_groups.join(',')}) AND (#{filter}) GROUP BY seizures.id", 
                      form_id ])
    end
  end
  
  def [](key)
    lines[:values][key]
  end
  
  def has_key?(key)
    lines[:keys].include?(key)
  end
  
  def keys
    lines[:keys]
  end
  
  def id_for(key)
    lines[:ids][key]
  end
  
  def method_missing(meth, *args)
    if [:'form_id=', :'user_id='].include?(meth)
      super
    else
      if meth.to_s =~ /^([^=]*)=$/
        key = $1.to_sym
        lines[:values][key] = args.shift
      else
        super
      end
    end
  end
  
  def after_save
    # save lines
    @lines[:values].each do |k,v|
      if @lines[:ids][k]
        # update line
        line = FormLine(@lines[:ids][k])
        line[:value] = v
        unless line.save
          # FIXME : what do we do with these errors ?
          errors.add("#{k}", "Value could not be saved")
        end
      else
        # create new line
        if line = FormLine.create(:key=>"#{k}", :value=>v, :seizure_id=>self.id)
          @lines[:ids][k] = line[:id]
        else
          puts "ERROR. Could not create line #{k}"
          errors.add("#{k}", "Value could not be saved")
        end
      end
    end
  end
  
  private
  
  def lines
    if @lines
      @lines
    else
      @lines = {:ids=>{}, :values=>{}, :keys=>[]}
      form_lines.each do |r|
        key = r[:key].to_sym
        @lines[:values][key] = r[:value]
        @lines[:ids   ][key] = r[:id]
        @lines[:keys  ] << key unless @lines[:keys].include?(key)
      end
      @lines
    end
  end
end