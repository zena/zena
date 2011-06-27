class Acl < ActiveRecord::Base
  # Used during script compilation
  attr_reader :node, :params
  # List of access actions, ordered for their use in the form.
  ACTIONS = %w{read update create delete}
  ACTION_FROM_METHOD = Hash[:get,'read',:put,'update',:post,'create',:delete,'delete']

  before_validation :set_defaults
  before_save   :set_visitor_id, :set_site_id
  belongs_to    :exec_group, :class_name => 'Group', :foreign_key => 'exec_group_id'
  belongs_to    :group
  validate      :validate_acl

  include Zena::Acts::Secure
  include RubyLess

  safe_method :params  => Zena::Use::ZafuSafeDefinitions::ParamsDictionary

  def safe_method_type(signature, receiver = nil)
    if type = super
      type
    elsif type = node.safe_method_type(signature)
      type.merge(:method => "@node.#{type[:method]}")
    else
      nil
    end
  end

  def authorize?(base_node, params)
    res = Node.find_by_sql(eval(make_query(base_node, params).to_s))
    if res.empty?
      nil
    else
      secure_result(res.first)
    end
  end

  def exec_skin_zip
    exec_skin ? exec_skin.zip : nil
  end

  def exec_skin
    @exec_skin ||= secure(Skin) { Skin.find(exec_skin_id) }
  end

  protected
    def set_defaults
      self.format = 'html' if format.blank?
      self.mode = '' if mode.nil?
    end

    def set_visitor_id
      self.user_id = visitor.id
    end

    def set_site_id
      self.site_id = current_site.id
    end

    def validate_acl
      make_query(visitor.prototype, {})
    end

    def make_query(node, params)
      @node   = node
      @params = params
      # We add a stupid order clause to avoid the 'order by title' thing.
      query = Node.build_query(:first, self.query + ' order by id asc',
        :node_name       => '@node',
        :main_class      => @node.virtual_class,
        :rubyless_helper => self
      )
      # Find only the current node amongst all the allowed nodes.
      query.add_filter("#{query.table}.zip = [[params[:id]]]")
      query
    rescue ::QueryBuilder::Error => err
      if err.message =~ /\AException raised while processing '.*?' \((.+)\)\Z/m
        errors.add(:query, $1)
      else
        errors.add(:query, err.message)
      end
      nil
    rescue ::RubyLess::Error => err
      errors.add(:query, err.message)
      nil
    end
end
