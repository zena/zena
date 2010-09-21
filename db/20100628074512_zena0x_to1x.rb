# ======= mock
class DocumentContent < ActiveRecord::Base

  def transfer_attachment(version)
    # own attachment
    atta = AttachmentTransfer.create(
      :filename   => name,
      :site_id    => site_id,
      :user_id    => version.user_id,
      :created_at => version.created_at,
      :updated_at => version.updated_at
    )
    if atta.new_record?
      puts "Failed to create Attachment for Version #{version.id}\n"
    else
      site_data = "#{SITES_ROOT}#{current_site.data_path}/full/"
      new_path = site_data + Versions::SharedAttachment.filepath(atta.id, name)

      digest = Digest::SHA1.hexdigest(self[:id].to_s)
      fname = name.gsub(/[^a-zA-Z\-_0-9]/,'')
      old_path = site_data + "#{digest[0..0]}/#{digest[1..1]}/#{digest[2..2]}/#{fname}"

      if File.exist?(old_path)
        FileUtils::mkdir_p(File.dirname(new_path))
        FileUtils::mv(old_path, new_path)

        cont_dir = File.dirname(old_path)
        while Dir.empty?(cont_dir) do
          FileUtils::rmtree(cont_dir)
          cont_dir = File.dirname(cont_dir)
        end
      else
        puts "Missing file for version #{version.id} (#{name})"
      end

      self.class.connection.execute "UPDATE versions SET attachment_id = #{atta.id} WHERE id = #{version.id}"
    end
  end
end

class ImageContent < DocumentContent
end

class TextDocumentContent < DocumentContent
end

class ContactContent < ActiveRecord::Base
end

# Load current site first
Site

class PropTransfer < Hash
  def to_json(*args)
    { 'json_class' => Property::Properties.name, 'data' => Hash[self] }.to_json(*args)
  end
end
# Monkey patch
class Site

  # Rebuild property indices for the Site. This method uses the Worker thread to rebuild and works on
  # chunks of 50 nodes.
  #
  # The visitor used during index rebuild is the anonymous user.
  def migrate_data(nodes = nil, page = nil, page_count = nil)
    if !nodes
      Site.logger.error("\n----------------- MIGRATE DATA FOR SITE #{host} -----------------\n")
      Zena::SiteWorker.perform(self, :migrate_data)
    else
      # do things
      page ||= 0
      printf("%3i / %-3i", page, page_count)
      $stdout.flush
      nodes.each do |node|
        node.versions.each do |version|
          prop = PropTransfer.new
          transfer_basic_attributes(version, prop)

          if node.kind_of?(Image)
            doc = version.content(DocumentContent)
            doc.transfer_attachment(version) if version.content_id.blank? # own attachment
            transfer_document_attributes(version, doc, prop)

            transfer_image_attributes(version, doc, prop)
          elsif node.kind_of?(Template)
            prop['ext'] = 'zafu'
            prop['content_type'] = 'text/zafu'
            if doc = version.content(TemplateContent)
              prop['target_klass'] = doc.klass
              prop['format']       = doc.format
              prop['mode']         = doc.mode
              prop['tkpath']       = doc.tkpath
            end
          elsif node.kind_of?(TextDocument)
            doc = version.content(DocumentContent)
            transfer_document_attributes(version, doc, prop)

          elsif node.kind_of?(Document)
            doc = version.content(DocumentContent)
            doc.transfer_attachment(version) if version.content_id.blank? # own attachment
            transfer_document_attributes(version, doc, prop)

          elsif node.kind_of?(BaseContact)
            doc = version.content(ContactContent)
            transfer_contact_attributes(version, doc, prop)
          end

          prop.reject! {|k,v| v.blank? }

          connection.execute "UPDATE versions SET properties = #{connection.quote(prop.to_json)} WHERE id = #{version.id}"
        end

        connection.execute "UPDATE idx_templates SET version_id = (SELECT id FROM versions WHERE node_id = #{node.id} ORDER BY status DESC, updated_at DESC LIMIT 1) WHERE node_id = #{node.id}"
        print('.')
        $stdout.flush
      end
      puts "\n"
    end

    true
  end

  def transfer_basic_attributes(version, prop)
    prop['title']   = version.idx_text_high
    prop['summary'] = version.idx_text_medium
    prop['text']    = version.idx_text_low
    version.dyna.each do |key, value|
      prop[key] = value unless value.blank?
    end
  end

  def transfer_document_attributes(version, doc, prop)
    unless doc
      puts "Missing DocumentContent for version #{version.id} (#{version.idx_text_high})"
      return
    end

    %w{content_type ext size}.each do |key|
      prop[key] = doc.send(key)
    end
  end

  def transfer_image_attributes(version, doc, prop)
    unless doc
      puts "Missing ImageContent for version #{version.id} (#{version.idx_text_high})"
      return
    end

    %w{width height}.each do |key|
      prop[key] = doc.send(key)
    end

    if exif = doc['exif'] && !exif.blank?
      prop['exif'] = ExifData.json_create(
        'json_class' => 'ExifData',
        'data' => exif
      )
    end
  end

  def transfer_contact_attributes(version, doc, prop)
    unless doc
      puts "Missing ContactContent for version #{version.id} (#{version.idx_text_high})"
      return
    end

    %w{first_name name address country telephone mobile email birthday}.each do |key|
      prop[key] = doc.send(key)
    end

    prop['postal_code'] = doc.zip
    prop['town'] = doc.city
  end
end

class AttachmentTransfer < ActiveRecord::Base
  set_table_name :attachments
  self.record_timestamps = false
end

# Load current version model
Version

# Monkey patch
class Version
  def dyna
    @dyna ||= begin
      if new_record?
        @dyna = {}
      else
        sql = "SELECT `key`,`value` FROM dyn_attributes WHERE owner_id = '#{id}'"
        @dyna = {}
        rows = connection.select_all(sql, "dyn_attributes Load").map! do |record|
          @dyna[record['key']] = record['value']
        end
      end
      @dyna
    end
  end

  def content(klass)
    @content ||= begin
      if self[:content_id]
        klass.find_by_version_id(self[:content_id])
      else
        klass.find_by_version_id(self[:id])
      end
    end
  end

end

class Zena0xTo1x < ActiveRecord::Migration


  def self.up
    remove_column :versions, :type

    Site.all.each do |site|
      puts "\n----------------- MIGRATE DATA FOR SITE #{site.host} (#{Node.count(:conditions => ['site_id = ?', site.id])} nodes) -----------------\n"
      Thread.current[:visitor] = site.su
      site.migrate_data
    end
  end

  def self.down
  end
end
