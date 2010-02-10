class PropretyGenerator < MigrationGenerator

  def initialize(runtime_args, runtime_options={})
    super(["dynamo=rety_migration"])
  end

  def manifest
    record do |m|
      m.migration_template( 'migration.rb', 'db/migrate')
    end
  end
end