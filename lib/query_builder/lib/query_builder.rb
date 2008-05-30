require 'rubygems'

if false
  require 'ruby-debug'
  Debugger.start
end

=begin rdoc
Syntax of a query is "CLASS [where ...|] [in ...|from SUB_QUERY|]"
=end
class QueryBuilder
  attr_reader :tables, :filters, :errors, :join_tables, :distinct
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
    @join_tables = {}
    @table_counter = {}
    @filters = []
    # list of tables that need to be added for filter clauses (should be added only once per part)
    @needed_tables = {}
    # list of tables that need to be added through a join (should be added only once per part)
    @needed_join_tables = {}
    
    @errors  = []
    
    @main_table ||= 'objects'
    
    @select  = []
    
    @ignore_warnings = opts[:ignore_warnings]
    
    if @query == nil || @query == ''
      elements = [main_table]
    else
      elements = @query.split(' from ')
      last_element = elements.last
      last_element, offset = last_element.split(' offset ')
      last_element, limit  = last_element.split(' limit ')
      last_element, order  = last_element.split(' order by ')
      elements[-1], group  = last_element.split(' group by ')
    end
    
    
    # In order to know the table names of the dependencies, we need to parse it backwards.
    # We first find the closest elements, then the final ones. For example, "pages from project" we need
    # project information before getting 'pages'. 
    elements.reverse!
    
    elements.each_index do |i|
      parse_part(elements[i], i == 0) # yes, is_last is first (parsing reverse)
    end
    @distinct ||= elements.size > 1
    @select << "#{table}.*"
    @limit    = parse_limit_clause(opts[:limit] || limit)
    @offset ||= parse_offset_clause(offset)
    
    merge_alternate_queries(alt_queries) if alt_queries
    
    
    @group = parse_group_clause(group) if group
    @order = parse_order_clause(order || default_order_clause)
    
    after_parse unless opts[:skip_after_parse]
    @filters.compact!
  end
  
  def to_sql
    return nil if !valid?
    return "SELECT #{@main_table}.* FROM #{@main_table} WHERE 0" if @tables.empty? # all alternate queries invalid and 'ignore_warnings' set.
    
    table_list = []
    @tables.each do |t|
      table_name = t.split(/\s+/).last # objects AS ob1
      if joins = @join_tables[table_name]
        table_list << "#{t} #{joins.join(' ')}"
      else
        table_list << t
      end
    end
    
    if @distinct
      @group ||= @tables.size > 1 ? " GROUP BY #{table}.id" : " GROUP BY id"
    end
    
    "SELECT #{@select.join(',')} FROM #{table_list.flatten.join(',')}" + (@filters == [] ? '' : " WHERE #{@filters.reverse.join(' AND ')}#{@group}#{@order}#{@limit}#{@offset}")
  end
  
  def valid?
    @errors == []
  end
  
  protected
    
    def main_table
      @@main_table
    end
  
    def parse_part(part, is_last)
      add_table(main_table)
      
      rest,   context = part.split(' in ')
      clause, filters = rest.split(/\s+where\s+/)
      
      parse_filters(filters) if filters
      parse_context(context, is_last) if context # .. in project
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
              if fld = field_or_param(part, table, :filter) # we need to inform if we are looking for 'null' related field/param
                fld
              elsif fld.nil?
                @errors << "invalid field or value '#{part}'"
                nil
              else
                nil
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
        if clause =~ /^\s*([^\s]+) (ASC|asc|DESC|desc)/
          fld_name, direction = $1, $2
          if fld = map_field(fld_name, table, :order)
            res << "#{fld} #{direction.upcase}"
          elsif fld.nil?
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
    
    def parse_group_clause(field)
      return nil unless field
      if fld = map_field(field, table, :group)
        " GROUP BY #{fld}"
      else
        @errors << "invalid field '#{field}'"
        nil
      end
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
        @join_tables[first_table] ||= []
        @join_tables[first_table] << "#{type} JOIN #{second_table} ON #{clause.gsub('TABLE1',table(table1)).gsub('TABLE2',table(table2))}"
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
      if valid?
        counter = 1
      else
        if @ignore_warnings
          # reset current query
          @tables   = []
          @join_tables = {}
          @filters  = []
          @errors   = []
          @distinct = nil
        end
        counter = 0
      end
      
      if @filters.compact == []
        filters = []
      else
        filters = [@filters.compact.reverse.join(' AND ')]
      end
      
      alt_queries.each do |query|
        @errors += query.errors unless @ignore_warnings
        next unless query.valid?
        query.filters.compact!
        next if query.filters.empty?
        counter += 1
        merge_tables(query)
        @distinct ||= query.distinct
        filters << query.filters.reverse.join(' AND ')
      end
      
      @alt_filters = filters
      
      @tables.uniq!
      
      if counter > 1
        @distinct = @tables.size > 1
        @filters  = ["((#{filters.join(') OR (')}))"]
      else
        @filters  = filters
      end
    end
    
    def merge_tables(sub_query)
      @tables += sub_query.tables
      sub_query.join_tables.each do |k,v|
        @join_tables[k] ||= []
        @join_tables[k] << v
      end
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
    
    def context_filter_fields(clause, is_last = false)
      nil
    end
    
    def parse_context(clause, is_last = false)
      
      if fields = context_filter_fields(clause, is_last)
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
    def field_or_param(fld, table_name = table, context = nil)
      if table_name
        map_field(fld, table_name, context)
      else
        map_parameter(fld)
      end
    end
    
    # Overwrite this and take car to check for valid fields.
    def map_field(fld, table_name, context = nil)
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