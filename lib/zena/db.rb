# FIXME: we should patch the connection adapters instead of having 'case, when' evaluated each time
# For example:
# module ActiveRecord
#   module ConnectionAdapters
#     class MysqlAdapter
#       include Zena::Db::MysqlAdditions
#     end
#   end
# end


module Zena
  klass = ActiveRecord::Base.configurations[RAILS_ENV]['adapter'].capitalize
  # Loads the wrong adaper when running rake tasks (RAILS_ENV not correct ?)
  # Is this fixed ? If not, use 
  # ActiveRecord::Base.connection.class.name.split('::').last[/(.+)Adapter/,1].downcase
  begin
    klass = Zena.resolve_const("Zena::DbHelper::#{klass}")
  rescue NameError
    raise NameError.new("Could not find db helper 'Zena::DbHelper::#{klass}'.")
  end

  Db = klass
end # Zena