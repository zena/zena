class Acl < ActiveRecord::Base
  ACTIONS = %w{create read update delete}

  belongs_to    :exec_group, :class_name => 'Group', :foreign_key => 'exec_group_id'
  belongs_to    :group
  validate      :validate_acl

  include Zena::Acts::Secure
  include RubyLess

  safe_method :params  => Zena::Use::ZafuSafeDefinitions::ParamsDictionary

  def safe_method_type(signature, receiver = nil)
    if type = super
      type
    elsif type = base_node.safe_method_type(signature)
      type.merge(:method => "@node.#{type[:method]}")
    else
      nil
    end
  end

  def self.new(attrs = {})
    super({}.merge(attrs))
  end

  def authorize?(base_node, params)
    Node.do_find(:first, eval(make_query.to_s))
  end

  def exec_skin_zip
    exec_skin ? exec_skin.zip : nil
  end

  def exec_skin
    secure(Skin) { Skin.find(exec_skin_id) }
  end

  protected
    def validate_acl
      make_query(visitor.prototype, {})
    end

    def make_query(node, params)
      @node   = node
      @params = params
      Node.build_query(:first, query,
        :node_name       => '@node',
        :main_class      => @node.virtual_class,
        :rubyless_helper => self
      )
    rescue ::QueryBuilder::Error => err
      errors.add(:query, err.message)
      nil
    rescue ::RubyLess::Error => err
      errors.add(:query, err.message)
      nil
    end
end
