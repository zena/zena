=begin rdoc
A version implements versioning and permits multiple publications (one for each language).

=== Status

A version's status changes over time. A version usually starts by being a 'redaction', these eventually a 'proposition', etc. The version's status changes by executing actions on the node (publish, remove, etc). Have a look at Acts::As::Multiversion for details. Zena::Status are :

pub (50)::  version is published (can be seen by all readers)
prop (40):: proposed for publication (seen only by the members of the publish group of the node)
prop_with (35):: document proposed with the redaction. Will be automatically published/removed with the redaction.
red (30):: version is being written (the redaction is only seen by its author)
rep (20):: replaced by a newer version (can be an elligible version for rollback)
rem (10):: removed (from a rollback)
del (0):: this is like 'moved to trash'

=== Version attributes

title:: Node title.
comment:: The comment is a little word saying what this particular version is about or a full text on all the modifications done or to be done or anything usefull that should be communicated inside the team.
text:: The text is the full content of a version. The text usually contains zazen formatted text (textile with additions). See Zazen for details.

=== Dynamic attributes

Any attribute written using version.dyn[:blah] = 'some text' is stored as a dynamic attribute. See DynAttributes for details.

== Content
If a we need to create a more sophisticated version class, all the required fields go in a 'content' class, like
#DocumentContent stores document type and size for #DocumentVersion. See #Document for the details on the relation between Version and Content.
=end
class Version < ActiveRecord::Base
  include Zena::Use::Dates::ModelMethods
  parse_date_attribute :publish_from

  # readable
  attr_public        :title, :text, :summary, :comment, :created_at, :updated_at, :publish_from, :status,
                     :wgroup_id, :pgroup_id, :zip, :lang, :user_zip
  # writable
  attr_accessible    :title, :text, :summary, :comment, :publish_from, :lang, :status, :content_attributes, :dyn_attributes
  zafu_context       :author => "Contact", :user => "User", :node => "Node"

  acts_as_version
  belongs_to            :user
  before_validation     :version_before_validation
  validates_presence_of :user, :site_id
  validate              :valid_version
  after_save            :save_content
  after_destroy         :destroy_content
  before_create         :set_number

  include Zena::Use::DynAttributes::ModelMethods

  class << self
    # Some #Version sub-classes need to have more specific content than just 'text' and 'summary'.
    # this content is stored in a delegate 'content' object found with the 'content_class' class method
    def content_class
      nil
    end
  end

  def author
    user.contact
  end

  # FIXME: This should not be needed ! Remove when find by id is cached.
  def set_node(node)
    @node ||= node
  end

  def user_zip
    user_id
  end

  def zip
    "#{node.zip}.#{number}"
  end

  # Return the content for the version. Can it's 'own' content or the same as the version this one was copied from.
  def content
    return nil unless content_class
    return @content if @content
    if self[:content_id]
      @content = content_class.find_by_version_id(self[:content_id])
      @content.preload_version(self) if @content
    else
      @content = content_class.find_by_version_id(self[:id])
      @content.preload_version(self) if @content
    end
    unless @content
      # create new content
      @content = content_class.new
      self[:content_id] = nil
      @content.preload_version(self)
      @redaction_content = @content
    end
    @content
  end

  # Return the version's own content or creates a new one so it can be edited.
  def redaction_content
    return @redaction_content if @redaction_content
    return nil unless content_class
    @content = content
    if @content && @content[:version_id] == self[:id]
      # own content, make sure no published version links to this content
      if !new_record? && slave_version = Version.find(:first, :select=>'id', :conditions=>["content_id = ?",self[:id]])
        # shared content, we need to build our own and alter others:
        #
        # 1. Current state
        #   version[@id = A, @content_id = nil] ===> content[@version_id = A] <--- version[@content_id = A,   @id = B]
        #
        # 2. Changes to
        #   version[@id = A, @content_id = B  ] ---> content[@version_id = B] <=== version[@content_id = nil, @id = B]
        #
        # Whatchout: we could have a race condition here...
        old_master_id = self[:id]
        new_master_id = slave_version[:id]
        content_id    = @content[:id]
        # version[@id = B, @content_id => nil]
        Version.connection.execute "UPDATE #{Version.table_name} SET content_id = NULL WHERE id = #{new_master_id}"
        # version[@id = A, @content_id => B]
        Version.connection.execute "UPDATE #{Version.table_name} SET content_id = #{new_master_id} WHERE id = #{old_master_id}"
        # content[@version_id => B]
        Version.connection.execute "UPDATE #{@content.class.table_name} SET version_id = #{new_master_id} WHERE id = #{content_id}"

        # content shared, make it our own
        @old_content = @content # keep the old one in case we cannot save and need to rollback
        @content = @old_content.clone
        self[:content_id]     = nil
        @content[:version_id] = nil # will be set on save
        @content.preload_version(self)
      end
    elsif @content
      # content shared, make it our own
      @old_content = @content # keep the old one in case we cannot save and need to rollback
      @content = @old_content.clone
      self[:content_id]     = nil
      @content[:version_id] = nil # will be set on save
      @content.preload_version(self)
    else
      # create new content
      @content = content_class.new
      self[:content_id] = nil
      @content.preload_version(self)
    end
    @redaction_content = @content
  end

  def content_class
    self.class.content_class
  end

  def content_attributes=(h)
    if redaction_content
      redaction_content.attributes = h
    else
      # ignore
    end
  end

  # Return a new redaction from this version
  def clone(new_attrs)
    ignore_attributes = self.attributes_to_ignore_on_clone
    attrs = attributes.dup.reject {|k,v| ignore_attributes.include?(k.to_s) }
    attrs = attrs.merge(new_attrs)

    new_clone = self.class.new(attrs)
    protected_attributes_on_clone.each do |k,v|
      new_clone.send("#{k}=", v)
    end
    new_clone
  end

  # List of attribute keys to export in a zml file.
  def export_keys
    {
      :zazen => {'v_title' => title, 'v_text' => text}.merge(Hash[*dyn.map{|k,v| ["d_#{k}", v]}.flatten]),
      :dates => {},
    }
  end

  def attributes_to_ignore_on_clone
    # /_ok$/ ?
    %w{ user_id type created_at updated_at id }
  end

  def protected_attributes_on_clone
    { 'content_id' => (content_class ? (content_id || id) : nil),
      'number'     => nil,
      'user_id'    => visitor.id,
      'node'       => self.node,
      'dyn'        => self.dyn,
      'status'     => Zena::Status[:red],
      'lang'       => visitor.lang }
  end

  # Return true if we would need to create a new version or re-edit depending
  # on the attributes
  def would_edit?(new_attrs)
    new_attrs.each do |k,v|
      next if ['status', 'publish_from'].include?(k.to_s)
      if k.to_s == 'content_attributes'
        return true if content.would_edit?(v)
      elsif k.to_s == 'dyn_attributes'
        return true if dyn.would_edit?(v)
      elsif self.class.attr_public?(k.to_s)
        return true if field_changed?(k, self.send(k), v)
      end
    end
    false
  end

  # Return true if the version has been edited (not just status / publication date change)
  # TODO: test
  def edited?
    new_record? || (changes.keys - ['status', 'publish_from'] != []) || (@redaction_content && @redaction_content.changed?)
  end

  def should_save?
    new_record? || changed? || (@redaction_content && @redaction_content.changed?)
  end

  private
    def set_number
      last_record = node.id ? self.connection.select_one("select number from #{self.class.table_name} where node_id = '#{node[:id]}' ORDER BY number DESC LIMIT 1") : nil
      self[:number] = (last_record || {})['number'].to_i + 1
    end

    def save_content
      if @content
        @content[:version_id] ||= self[:id]
        @content.save_without_validation # validations checked with 'valid_content'
      else
        true
      end
    end

    def destroy_content
      content.destroy if content_class && content.can_destroy?
    end

    # Set version number and site_id before validation tests.
    def version_before_validation
      self[:site_id] = visitor.site.id
      return unless node
      # [ why do we need these defaults now ? (since rails 1.2)
      self.text    ||= ""
      self.title     = node.name if self.title.blank?
      self.summary ||= ""
      self.comment ||= ""
      self.type    ||= self.class.to_s

      self.lang      = visitor.lang if self.lang.blank?
      self.status  ||= current_site.auto_publish? ? Zena::Status[:pub] : Zena::Status[:red]
      self.publish_from ||= Time.now if self.status == Zena::Status[:pub]
      self.user_id = visitor[:id] if new_record?

      if @content
        @content[:site_id] = self[:site_id]
      end
    end

    # Make sure the version and it's related content are in a correct state.
    def valid_version
      errors.add('lang', 'not valid') unless visitor.site.lang_list.include?(self[:lang])
      errors.add('node', "can't be blank") unless node
      # validate content
      # TODO: we could use autosave here
      if @content && !@content.valid?
        @content.errors.each do |attribute,message|
          if attribute.to_s == 'base'
            errors.add(:base, message)
          else
            attribute = "content_#{attribute}"
            errors.add(attribute, message) unless errors[attribute] # FIXME: rails 3: if errors[attribute].empty?
          end
        end

        if @old_content
          @content = @old_content # rollback initial content
        else
          # clean empty content
          @content = content_class.new
          @content.preload_version(self)
          self[:content_id] = nil
          @redaction_content = @content
        end
      end
    end
end
