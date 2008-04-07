=begin
icons from nodes from project

SELECT nd1.id, nd1.project_id, nd1.name, nd1.kpath FROM nodes as nd1, links AS lk1, nodes as nd2 WHERE (lk1.relation_id = 4 AND lk1.target_id = nd1.id AND lk1.source_id = nd2.id) AND (nd2.project_id = 11)
=end

class QueryBuilder
  attr_reader :tables, :filters
  @@main_table = 'objects'
  
  class << self
    def set_main_table(table_name)
      @@main_table = table_name.to_s
    end
  end
  
  def initialize(query)
    @query   = query
    @tables  = []
    @table_counter = {}
    @filters = []
    @main_table ||= 
    add_table(main_table)
    if @query == nil || @query == ''
      elements = [main_table]
    else
      elements = @query.split(' from ')
    end
    elements.each_index do |i|
      parse_element(elements[i], i > 0 || i == elements.size - 1)
    end
    after_parse
    @filters.compact!
  end
  
  def to_sql
    "SELECT #{table_at(main_table,0)}.* FROM #{@tables.join(',')}" + (@filters == [] ? '' : " WHERE #{@filters.join(' AND ')}")
  end
  
  protected
    def main_table
      @@main_table
    end
  
    def parse_element(txt, use_default)
      clause, filters = txt.split(/\s+where\s+/)
      
      @filters << relation(clause)
      
      @filters << default_filter(clause) if use_default
      
      parse_filters(filters) if filters
    end
    
    def parse_filters(txt)
      txt.split(/\s+and\s+/).each do |clause|
        # [field] [=|>]
        if clause =~ /("[^"]*"|'[^']*'|\w+)\s*(like|is not|is|>=|<=|<>|<|=|>|lt|le|eq|ne|ge|gt)\s*("[^"]*"|'[^']*'|\w+)/
          # TODO: add 'match' parameter (#105)
          parts = [$1,$3]
          op = {'lt' => '<','le' => '<=','eq' => '=','ne' => '<>','ge' => '>=','gt' => '>'}[$2] || $2
          parts.map! do |part|
            if ['"',"'"].include?(part[0..0])
              map_literal(part[1..-2])
            elsif part == 'null'
              "NULL"
            else
              map_field(part)
            end
          end.compact!
          
          if parts.size == 2 && parts[0] != 'NULL'
            # ok, no value/field error
            if op[0..2] == 'is' && parts[1] != 'NULL'
              # error
            else
              @filters << parts.join(" #{op} ")
            end
          else
            # value/field error
          end
        else
          # invalid clause format
        end
      end
    end
    
    def add_table(table_name)
      if !@table_counter[table_name]
        @tables << table_name
        @table_counter[table_name] = 0
      else  
        @table_counter[table_name] += 1
        @tables << "#{table_name} AS #{table(table_name)}"
      end
    end
    
    def table_counter(table_name)
      @table_counter[table_name] ||= 0
    end
    
    def table_at(table_name, index)
      if index < 0 || index > table_counter(table_name)
        raise Exception.new("Query error")
      end
      index == 0 ? table_name : "#{table_name[0..1]}#{index}"
    end
    
    def table(table_name=main_table, index=0)
      table_at(table_name, table_counter(table_name) + index)
    end
    
    # ******** Overwrite these **********
    
    def after_parse
      # do nothing
    end

    def direct_relation(txt)
      return nil
    end

    def direct_filter(txt)
      return nil
    end

    def relation(txt)
      return nil
    end
    
    def map_literal(value)
      value.inspect
    end
    
    def map_field(fld)
      "#{table}.#{fld.gsub(/[^a-z_]/,'')}"
    end
end