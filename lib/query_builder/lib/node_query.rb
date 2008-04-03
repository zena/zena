require File.join(File.dirname(__FILE__) , 'query_builder.rb')

class NodeQuery < Query
  set_main_table :nodes
  
  def initialize(query)
    @table_name = 'nodes'
    super(query)
  end
  
  private
    def after_parse
      @filters << "\#{secure_scope('#{table_at(main_table,1)}')}"
    end
end