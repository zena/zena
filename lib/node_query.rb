require File.join(File.dirname(__FILE__) , 'query_builder', 'lib', 'query_builder')

class NodeQuery < QueryBuilder
  attr_reader :context
  set_main_table :nodes
  
  def initialize(query, context = {})
    @table_name = 'nodes'
    @context    = context
    @node_name  = context[:node_name]
    super(query)
  end
  
  # Build joins and filters from a relation.
  def relation(txt)
    direct_relation(txt) ||
    direct_filter(txt)   ||
    join_relation(txt)
  end
  
  # default relation filter is to search in the current node's children
  def default_filter(clause)
    if !direct_relation(clause)
      direct_relation('parent')
    else
      nil
    end
  end
  
  def after_parse
    @filters << "\#{secure_scope('#{table_at(main_table,0)}')}"
  end
  
  private
    
    # Relations that can be resolved without a join
    def direct_relation(txt)
      case txt
      when 'parent'
        "#{table}.parent_id = \#{#{@node_name}.id}"
      when 'project'
        "#{table}.project_id = \#{#{@node_name}.get_project_id}"
      else
        nil
      end
    end

    # Direct filter
    def direct_filter(rel)
      case rel
      when main_table
        nil
      ######## special cases #######
      else  
        if klass = Node.get_class(rel)
          ######## class filters #######
          "#{table}.kpath LIKE '#{klass.kpath}%'"
        else
          # unknown class
          nil
        end
      end
    end

    # Filters that need a join
    def join_relation(txt)
      case txt
      when 'recipients'
        add_table('links')
        add_table(main_table)
        "#{table('links')}.relation_id = 4 AND #{table('links')}.source_id = #{table(main_table,-1)}.id AND #{table('links')}.target_id = #{table}.id"
      else
        nil
      end
    end
end