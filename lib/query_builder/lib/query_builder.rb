=begin
icons from nodes from project

SELECT nd1.id, nd1.project_id, nd1.name, nd1.kpath FROM nodes as nd1, links AS lk1, nodes as nd2 WHERE (lk1.relation_id = 4 AND lk1.target_id = nd1.id AND lk1.source_id = nd2.id) AND (nd2.project_id = 11)
=end
require 'rubygems'

if false
  require 'ruby-debug'
  Debugger.start
end

=begin rdoc
Syntax of a query is "CLASS [where ...|] [in ...|from SUB_QUERY|]"
=end
class QueryBuilder
  attr_reader :tables, :filters, :errors
  @@main_table = 'objects'
  
  class << self
    def set_main_table(table_name)
      @@main_table = table_name.to_s
    end
  end
  
  def initialize(query, opts = {})
    if query.kind_of?(Array)
      @query = query[0]
      if query.size > 1
        alt_queries = query[1..-1].map {|q| self.class.new(q, opts.merge(:skip_after_parse => true))}
      end
    else
      @query = query
    end
    
    @tables  = []
    @table_counter = {}
    @filters = []
    # list of tables that need to be added for filter clauses (should be added only once per part)
    @needed_tables = {}
    # list of tables that need to be added through a join (should be added only once per part)
    @needed_join_tables = {}
    
    @errors  = []
    
    @main_table ||= 'objects'
    
    @select  = []
    
    if @query == nil || @query == ''
      elements = [main_table]
    else
      elements = @query.split(' from ')
      last_element = elements.last
      last_element, offset = last_element.split(' offset ')
      last_element, limit  = last_element.split(' limit ')
      elements[-1], order  = last_element.split(' order by ')
    end
    
    parts = elements.map do |e|
      e, context_filter = e.split(' in ')
      clause, filters = e.split(/\s+where\s+/)
      [clause, context_filter, filters]
    end
    
    # In order to know the table names of the dependencies, we need to parse it backwards.
    # We first find the closest elements, then the final ones. For example, "pages from project" we need
    # project information before getting 'pages'. 
    parts.reverse!
    
    parts.each do |e|
      #e[1] ||= default_context_filter(e[0])
      
      add_table(main_table)
      parse_part(e)
    end
    
    @select << "#{table}.*"
    @order  = parse_order_clause(order) || parse_order_clause(default_order_clause)
    @limit  = parse_limit_clause(opts[:limit] || limit)
    @offset ||= parse_offset_clause(offset)
    
    merge_alternate_queries(alt_queries) if alt_queries
    
    after_parse unless opts[:skip_after_parse]
    @filters.compact!
  end
  
  def to_sql
    return nil if !valid?
    "SELECT#{@distinct} #{@select.join(',')} FROM #{@tables.join(',')}" + (@filters == [] ? '' : " WHERE #{@filters.reverse.join(' AND ')}#{@group}#{@order}#{@limit}#{@offset}")
  end
  
  def valid?
    @errors == []
  end
  
  protected
    
    def main_table
      @@main_table
    end
  
    def parse_part(part)
      clause, context, filters = *part
      
      parse_filters(filters) if filters
      parse_context(context) if context # .. in project
      parse_relation(clause, context)
    end
    
    def parse_filters(txt)
      txt.split(/\s+and\s+/).each do |clause|
        # [field] [=|>]
        if clause =~ /("[^"]*"|'[^']*'|[\w:]+)\s*(like|not like|is not|is|>=|<=|<>|<|=|>|lt|le|eq|ne|ge|gt)\s*("[^"]*"|'[^']*'|[\w:]+)/
          # TODO: add 'match' parameter (#105)
          parts = [$1,$3]
          op = {'lt' => '<','le' => '<=','eq' => '=','ne' => '<>','ge' => '>=','gt' => '>'}[$2] || $2
          parts.map! do |part|
            if ['"',"'"].include?(part[0..0])
              map_literal(part[1..-2])
            elsif part =~ /^\d+$/
              map_literal(part)
            elsif part == 'null'
              "NULL"
            else
              if fld = field_or_param(part, table, op[0..2] == 'is') # we need to inform if we are looking for 'null' related field/param
                fld
              else
                @errors << "invalid field or value '#{part}'"
              end
            end
          end.compact!
          
          if parts.size == 2 && parts[0] != 'NULL'
            # ok, no value/field error
            if op[0..2] == 'is' && parts[1] != 'NULL'
              # error
              @errors << "invalid clause '#{clause}' ('is' only valid with 'null')"
            else
              @filters << parts.join(" #{op.upcase} ")
            end
          end
        else
          # invalid clause format
          @errors << "invalid clause '#{clause}'"
        end
      end
    end
    
    def parse_order_clause(order)
      return nil unless order
      res = []
      
      order.split(',').each do |clause|
        if clause =~ /^\s*(\w+) (ASC|asc|DESC|desc)/
          fld_name, direction = $1, $2
          if fld = map_field(fld_name, table)
            res << "#{@tables.size == 1 ? fld_name : fld} #{direction.upcase}"
          else
            @errors << "invalid field '#{fld_name}'"
          end
        elsif clause == 'random'
          res << "RAND()"
        else
          @errors << "invalid order clause '#{clause}'"
        end
      end
      res == [] ? nil : " ORDER BY #{res.join(', ')}"
    end
    
    def parse_limit_clause(limit)
      return nil unless limit
      if limit.kind_of?(Fixnum)
        " LIMIT #{limit}"
      elsif limit =~ /^\s*(\d+)\s*,\s*(\d+)/
        @offset = " OFFSET #{$1}"
        " LIMIT #{$2}"
      elsif limit =~ /(\d+)/
        " LIMIT #{$1}"
      else
        @errors << "invalid limit clause '#{limit}'"
        nil
      end
    end
    
    def parse_offset_clause(offset)
      return nil unless offset
      if !@limit
        # TODO: raise error ?
        @errors << "invalid offset clause '#{offset}' (used without limit)"
        nil
      elsif offset.strip =~ /^\d+$/
        " OFFSET #{offset}"
      else
        @errors << "invalid offset clause '#{offset}'"
        nil
      end
    end
    
    def add_table(table_name)
      if !@table_counter[table_name]
        @table_counter[table_name] = 0
        @tables << table_name
      else  
        @table_counter[table_name] += 1
        @tables << "#{table_name} AS #{table(table_name)}"
      end
    end
    
    # return a unique table name for the current sub-query context, adding the table when necessary
    def needs_table(table1, table2, filter)
      @needed_tables[table2] ||= {}
      @needed_tables[table2][table] ||= begin
        add_table(table2)
        @filters << filter.gsub('TABLE1', table).gsub('TABLE2', table(table2))
        table(table2)
      end
    end
    
    # versions LEFT JOIN dyn_attributes ON ...
    def needs_join_table(table1, type, table2, clause, join_name = nil)
      join_name ||= "#{table1}=#{type}=#{table2}"
      @needed_join_tables[join_name] ||= {}
      @needed_join_tables[join_name][table] ||= begin
        # define join for this part ('table' = unique for each part)
      
        first_table = table(table1)
      
        if !@table_counter[table2]
          @table_counter[table2] = 0
          second_table  = table2
        else
          @table_counter[table2] += 1
          second_table  = "#{table2} AS #{table(table2)}"
        end
      
        @tables.delete(first_table)
        @tables << "#{first_table} #{type} JOIN #{second_table} ON #{clause.gsub('TABLE1',table(table1)).gsub('TABLE2',table(table2))}"
        table(table2)
      end
    end
    
    def table_counter(table_name)
      @table_counter[table_name] || 0
    end
    
    def table_at(table_name, index)
      if index < 0
        return nil # no table at this address
      end
      index == 0 ? table_name : "#{table_name[0..1]}#{index}"
    end
    
    def table(table_name=main_table, index=0)
      table_at(table_name, table_counter(table_name) + index)
    end
    
    def merge_alternate_queries(alt_queries)
      counter = 1
      
      if @filters.compact == []
        filters = []
      else
        filters = [@filters.compact.reverse.join(' AND ')]
      end
      
      alt_queries.each do |query|
        @errors += query.errors
        next unless query.valid?
        query.filters.compact!
        next if query.filters.empty?
        counter += 1
        @tables += query.tables
        filters << query.filters.reverse.join(' AND ')
      end
      if counter > 1
        @filters  = ["((#{filters.join(') OR (')}))"]
        @distinct = " DISTINCT"
      else
        @filters  = [filters]
        @distinct = ""
      end
      @tables.uniq!
    end
    
    # ******** Overwrite these **********
    def default_context_filter(clause)
      nil
    end
    
    # Default sort order
    def default_order_clause
      nil
    end
    
    def after_parse
      # do nothing
    end
    
    def parse_relation(clause, context)
      return nil
    end
    
    def context_filter_fields(clause)
      nil
    end
    
    def parse_context(clause)
      if fields = context_filter_fields(clause)
        @filters << "#{field_or_param(fields[0])} = #{field_or_param(fields[1], table(main_table,-1))}" if fields != :void
      else
        @errors << "invalid context '#{clause}'"
      end
    end
    
    # Map a litteral value to be used inside a query
    def map_literal(value)
      value.inspect
    end
    
    # Map a field to be used inside a query
    def field_or_param(fld, table_name = table, is_null = false)
      if table_name
        map_field(fld, table_name, is_null)
      else
        map_parameter(fld)
      end
    end
    
    # Overwrite this and take car to check for valid fields.
    def map_field(fld, table_name, is_null=false)
      if fld == 'id'
        "#{table_name}.#{fld}"
      else
        # TODO: error, raise / ignore ?
      end
    end
    
    def map_parameter(fld)
      fld.to_s.upcase
    end
end