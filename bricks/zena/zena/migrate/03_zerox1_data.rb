require 'fileutils'
# ============================================ contact_contents
# migrate content to properties
class ContactContent < ActiveRecord::Base
  TRANSLATE_KEYS = {
    'name' => 'last_name',
    'zip'  => 'postal_code',
    'city' => 'locality',
  }
  def migrate(version)
    %w{first_name name address zip city telephone mobile email birthday country}.each do |key|
      value = self[key]
      next if value.blank?
      version.prop[TRANSLATE_KEYS[key] || key] = value
    end
  end
end

# ============================================ document_contents
# migrate page ref to attachments
class AttachmentMig < Versions::SharedAttachment
  set_table_name :attachments

  def filepath(format=nil)
    "#{SITES_ROOT}#{$site.data_path}/full/#{super()}"
  end
end

class VClassMig < ActiveRecord::Base
  set_table_name :roles
end

class UploadedFile < File
  attr_accessor :original_filename
end

# migrate content to properties
class DocumentContent < ActiveRecord::Base
  TRANSLATE_KEYS = {
    'exif_json' => 'exif'
  }

  # Disable type column
  def self.inheritance_column
    nil
  end

  def migrate_attachment(version)
    if !self.attachment_id
      # old path
      digest = Digest::SHA1.hexdigest(self[:id].to_s)
      # make sure name is not corrupted
      fname = name.gsub(/[^a-zA-Z\-_0-9]/,'')

      if File.exist?("#{SITES_ROOT}#{$site.data_path}/full") && !File.exist?("#{SITES_ROOT}#{$site.data_path}/full_old")
        FileUtils.mv("#{SITES_ROOT}#{$site.data_path}/full","#{SITES_ROOT}#{$site.data_path}/full_old")
      end
      old_path = "#{SITES_ROOT}#{$site.data_path}/full_old/#{digest[0..0]}/#{digest[1..1]}/#{digest[2..2]}/#{fname}"

      atta = AttachmentMig.new
      atta['user_id'] = version.user_id
      atta['site_id'] = version.site_id
      if type != 'TextDocumentContent'
        if File.exist?(old_path)
          file = UploadedFile.new(old_path)
          file.original_filename = fname
          atta.file = file
          atta.save
          self.attachment_id = atta.id
        else
          puts "Missing attachment file for node_id #{version.node_id} (#{version.idx_text_high})"
        end
      end
      self.save
    end
    version.attachment_id = self.attachment_id
  end

  def migrate(version)
    exif = self['exif_json']
    if !exif.blank?
      version.prop['exif'] = ExifData.json_create('data' => exif)
    end
    %w{size content_type ext width height}.each do |key|
      value = self[key]
      next if value.blank?
      version.prop[TRANSLATE_KEYS[key] || key] = value
    end
    migrate_attachment(version)
  end
end

# ============================================ dyn_attributes
class DynAttribute < ActiveRecord::Base
  set_table_name :dyn_attributes

  def migrate(version)
    version.prop[key] = value
  end
end

# ============================================ site_attributes
class SiteAttribute < ActiveRecord::Base
  set_table_name :site_attributes

  def migrate(site)
    site.prop[key] = value
  end
end

# ============================================ template_contents
# migrate content to properties
# rebuild index ==> should recreate idx_templates content
class TemplateContent < ActiveRecord::Base
  TRANSLATE_KEYS = {
    'klass' => 'target_klass'
  }
  def migrate(version)
    version['skin_id'] = version.node[:section_id]

    %w{format tkpath mode klass}.each do |key|
      value = self[key]
      next if value.blank?
      version.prop[TRANSLATE_KEYS[key] || key] = value
    end
  end
end

# ============================================ versions
class VersionMig < ActiveRecord::Base
  set_table_name :versions
  belongs_to :node, :class_name => 'NodeMig', :foreign_key => 'node_id'
  has_one :template_content, :foreign_key => 'node_id', :primary_key => 'node_id'

  include Property
  # Should be the same serialization as in Version and Site
  include Property::Serialization::JSON

  def contact_content
    @contact_content ||= ContactContent.find(:first,
      :conditions => ['version_id = ?', content_id || id]
    )
  end

  def document_content
    @document_content ||= DocumentContent.find(:first,
      :conditions => ['version_id = ?', content_id || id]
    )
  end

  def migrate!
    migrate_base
    migrate_contact
    migrate_document
    migrate_template
    migrate_dyn_attributes
    # Allow any property
    class << self.prop
      def validate
        # do nothing
        true
      end
    end

    if !save
      puts "Could not save version #{id} (#{idx_text_high}):"
      errors.each_error do |er,msg|
        puts "  [#{er}] #{msg}"
      end
    end
  end

  def migrate_base
    # migrate content to version properties
    prop['custom_a'] = node.custom_a unless node.custom_a.nil?
    prop['custom_b'] = node.custom_b unless node.custom_b.nil?
    prop['title']   = idx_text_high
    prop['summary'] = idx_text_medium
    prop['text']    = idx_text_low
    prop['ext']     = 'zafu' if node.kpath =~ /\ANDTT/
  end

  def migrate_contact
    if contact_content
      contact_content.migrate(self)
    end
  end

  def migrate_document
    if document_content
      document_content.migrate(self)
    end
  end

  def migrate_template
    if template_content
      template_content.migrate(self)
    end
  end

  def migrate_dyn_attributes
    DynAttribute.find(:all, :conditions => ["owner_table = 'versions' AND owner_id = ?", self.id]).each do |dyn|
      dyn.migrate(self)
    end
  end
end

class NodeMig < ActiveRecord::Base
  set_table_name :nodes
  has_many :versions, :class_name => 'VersionMig', :foreign_key => 'node_id'

  # Disable type column
  def self.inheritance_column
    nil
  end
end

# === dyn_attributes

class SiteMig < ActiveRecord::Base
  CHUNK_SIZE = 200
  has_many :site_attributes, :class_name => 'SiteAttribute', :foreign_key => 'owner_id'

  include Property

  set_table_name :sites

  def data_path
    "/#{self[:host]}/data"
  end

  def migrate!
    # needed by DocumentContent
    $site = self

    # Allow any property
    class << self.prop
      def validate
        # do nothing
        true
      end
    end

    migrate_nodes
    migrate_site
    if !save
      puts "Could not save site #{id} (#{host}):"
      errors.each_error do |er,msg|
        puts "  [#{er}] #{msg}"
      end
    end
  end

  def migrate_nodes
    node_count = NodeMig.count(:conditions =>['site_id = ?', id])
    puts "========================================== Start data migration to 1.0 for #{host} (#{node_count} nodes)"
    puts "========== creating virtual classes (Contact, Reference)"
    # Create Contact + Reference virtual classes
    ref_class = VClassMig.create(
      :name       => 'Reference',
      :kpath      => 'NR',
      :real_class => 'Node',
      :create_group_id => public_group_id,
      :site_id    => id
    )
    contact_class = VClassMig.create(
      :name       => 'Contact',
      :kpath      => 'NRC',
      :real_class => 'Node',
      :create_group_id => public_group_id,
      :site_id    => id
    )
    # Update nodes depending on Contact + Reference classes
    execute "UPDATE nodes SET vclass_id = #{ref_class.id} WHERE type = 'Reference' AND vclass_id IS NULL AND site_id = #{id}"
    execute "UPDATE nodes SET vclass_id = #{contact_class.id} WHERE type = 'Contact' AND vclass_id IS NULL AND site_id = #{id}"
    execute "UPDATE nodes SET type = 'Node' WHERE (type = 'Reference' or type = 'Contact') AND site_id = #{id}"

    page  = 0
    while true do
      nodes = NodeMig.find(:all,
        :conditions => ['site_id = ?', id],
        :limit  => CHUNK_SIZE,
        :offset => page * CHUNK_SIZE,
        :order  => 'id ASC'
      )
      break if nodes == []
      puts "========== migrating nodes #{(page * CHUNK_SIZE) + 1} to #{[((page+1) * CHUNK_SIZE), node_count].min}"
      nodes.each do |n|
        n.versions.each do |v|
          v.migrate!
        end
      end
      page += 1
    end

    # ============================================ nodes
    # 1. Set skin_id from skin name
    NodeMig.find(:all,
      :conditions => ['site_id = ? AND type = ?', id, 'Skin']
    ).each do |skin|
      execute "UPDATE nodes SET skin_id = #{skin.id} WHERE skin = '#{skin.name}'"
    end

    # 2. Set _id from name
    execute "UPDATE nodes SET _id = name WHERE site_id = #{id}"

    # 3. move custom_a, custom_b to idx_integer1, idx_integer2
    execute "UPDATE nodes SET idx_integer1 = custom_a, idx_integer2 = custom_b"
  end

  def migrate_site
    # ============================================ site_attributes
    # migrate to properties
    site_attributes.each do |attribute|
      attribute.migrate(self)
    end
  end

  private
    def execute(*args)
      self.class.connection.execute(*args)
    end
end


# This migration should be run in the 1.0 branch *AFTER* the migration
# to Zerox1Schema.
class Zerox1Data < ActiveRecord::Migration
  extend Zena::Acts::Secure
  def self.up
    if connection.tables.include?('contact_contents') && ContactContent.first
      # Need to migrate data
      if $Zerox1SchemaRunning
        raise "\n\n=> This is not an error:\n=> Please restart migration: a restart is needed before running Zerox1Data.\n\n"
      end
    else
      # Nothing to be done here
      puts "=>  No legacy data to migrate."
      return
    end

    # Prepare
    add_column :document_contents, :attachment_id, :integer unless DocumentContent.column_names.include?('attachment_id')

    DocumentContent.reset_column_information

    execute "UPDATE roles SET real_class = 'Node' WHERE real_class = 'Reference' OR real_class = 'Contact'"

    sites = SiteMig.all
    sites.each do |site|
      site.migrate!
    end

    # ============================================ roles
    # make properties from dyn_keys list ?

    execute "UPDATE roles SET type = 'VirtualClass'"

    puts %q{
======== Migration succeded.
***********************************************************************************
****************** You need to rebuild vhash, fullpath and index now! *************

=> rake zena:rebuild_vhash WORKER=false && rake zena:rebuild_fullpath WORKER=false && rake zena:rebuild_index WORKER=false

***********************************************************************************
}
  end
end
