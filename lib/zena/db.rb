module Zena
  klass = ActiveRecord::Base.configurations[RAILS_ENV]['adapter'].capitalize
  # Loads the wrong adaper when running rake tasks (RAILS_ENV not correct ?)
  # Is this fixed ? If not, use
  # ActiveRecord::Base.connection.class.name.split('::').last[/(.+)Adapter/,1].downcase
  begin
    Db = Zena.resolve_const("Zena::DbHelper::#{klass}")
  rescue NameError
    raise NameError.new("Could not find db helper 'Zena::DbHelper::#{klass}'.")
  end
end # Zena
