class VirtualClass < ActiveRecord::Base
  validate      :valid_virtual_class
  
  def to_s
    name
  end
  
  # check inheritance chain through kpath
  def kpath_match?(kpath)
    self.kpath =~ /^#{kpath}/
  end
  
  def new(*args)
    obj = real_class.new(*args)
    obj[:vclass_id] = self[:id]
    obj
  end
  
  def real_class
    klass = Module::const_get(self[:real_class])
    raise NameError unless klass.ancestors.include?(Node)
    klass
  end
  
  def with_exclusive_scope(scope, &block)
    @scope = scope
    res = yield
    @scope = nil
    res
  end
  
  def create(*args)
    if @scope
      real_class.with_exclusive_scope(@scope) {
        obj = self.new(*args)
        obj.save
        obj
      }
    else
      obj = self.new(*args)
      obj.save
      obj
    end
  end
  
  private
    def valid_virtual_class
      # validate real_class
      # set kpath
      # set site_id
      # validate uniqueness of name (scope = site_id)
      # validate create_group_id
    end
end
