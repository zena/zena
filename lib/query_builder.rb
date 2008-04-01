=begin
icons from nodes from project

SELECT nd1.id, nd1.project_id, nd1.name, nd1.kpath FROM nodes as nd1, links AS lk1, nodes as nd2 WHERE (lk1.relation_id = 4 AND lk1.target_id = nd1.id AND lk1.source_id = nd2.id) AND (nd2.project_id = 11)
=end

class Query
  attr_reader :tables, :filters
  def initialize(query)
    @query   = query
    @tables  = []
    @table_counter = {}
    @filters = []
    add_table('nodes')
    elements = @query.split(' from ')
    elements.each_index do |i|
      parse_element(elements[i], i == elements.size - 1)
    end
  end
  
  def to_sql
    "SELECT #{table_at('nodes',1)}.* FROM #{@tables.join(',')} WHERE #{@filters.join(' AND ')}"
  end
  
  private
  
    def parse_element(txt, is_last)
      clause, filters = txt.split(/\s+where\s+/)
      if is_last && !direct_filter(clause)
        # default direct filter is to search in the current node as parent for opened contexts
        @filters << direct_filter('parent')
      end
      if filter = direct_filter(clause) || filter = class_filter(clause)
        @filters << filter
      elsif proxy = relation_proxy(clause)
        add_table('links')
        add_table('nodes')
        src, trg, id = proxy
        @filters << "#{table('links')}.relation_id = #{id} AND #{table('links')}.#{src}_id = #{table('nodes',-1)}.id AND #{table('links')}.#{trg}_id = #{table('nodes')}.id"
      end
      parse_filters(filters) if filters
    end
    
    def parse_filters(txt)
      txt.split(/\s+and\s+/).each do |p|
        if p =~ /(\w+)\s*(=)\s*(\S+)/
          @filters << "#{table('nodes')}.#{$1}#{$2}#{$3}"
        else
          raise Exception.new('syntax error')
        end
      end
    end
    
    def relation_proxy(txt)
      if txt == 'recipients'
        return [:source, :target, 4]
      else
        return nil
      end
    end

    def direct_filter(txt)
      case txt
      when 'parent'
        return "#{table('nodes')}.parent_id = ID"
      when 'project'
        return "#{table('nodes')}.project_id = PROJECT_ID"
      end  
      return nil
    end
    
    def class_filter(txt)
      if txt == 'letters'
        return "#{table('nodes')}.kpath LIKE 'NPL%'"
      end
      return nil
    end
    
    def add_table(table_name)
      @table_counter[table_name] = table_counter(table_name) + 1
      @tables << "#{table_name} AS #{table(table_name)}"
    end
    
    def table_counter(table_name)
      @table_counter[table_name] ||= 0
    end
    
    def table_at(table_name, index)
      if index < 0 || index > table_counter(table_name)
        raise Exception.new("Query error")
      end
      "#{table_name[0..1]}#{index}"
    end
    
    def table(table_name, index=0)
      table_at(table_name, table_counter(table_name) + index)
    end
end


#puts Query.new('recipients from letters from project').to_sql
puts Query.new('letters where x = 3').to_sql