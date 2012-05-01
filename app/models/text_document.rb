=begin rdoc
Any document that can be edited as text (html file, script, source code) is a text document. The file content is not stored in an external file. It is kept in the version text. This means that the content of such a document can be edited by editing the version's text.

=== Version

The version class used by text documents is the TextDocumentVersion.

=== Content

Content (file data) is stored in the TextDocumentVersion. The content class (TextDocumentContent) is responsible for faking the exitence of a real file.
=end
class TextDocument < Document

  # Class Methods
  class << self
    # Return true if a new text document can be created with the content_type. Used by the superclass Document to choose the corret subclass when creating a new object.
    def accept_content_type?(content_type)
      (content_type =~ /^(text|image\/svg\+xml|x-javascript)/) && 
      (Zena::TYPE_TO_EXT[content_type.chomp] != ['rtf'])
    end

    # Return true if the content_type can change independantly from the file
    def accept_content_type_change?
      true
    end
  end # Class Methods


  def can_parse_assets?
    return ['text/css'].include?(content_type)
  end

  # Parse text content and replace all reference to relative urls ('img/footer.png') by their zen_path ('/en/image34.png')
  def parse_assets(text, helper, key)
    if key == 'text' && prop['content_type'] == 'text/css'
      res = text.dup
      # use skin as root
      skin = section

      # not in a Skin. Cannot replace assets in CSS.
      # error
      unless skin.kind_of?(Skin)
        errors.add('base', 'Cannot parse assets if not in a Skin.')
        return text
      end

      res.gsub!(/url\(\s*(.*?)\s*\)/) do
        match, src = $&, $1
        if src =~ /('|")(.*?)\1/
          quote, src = $1, $2
        else
          quote = "'"
        end
        if src[0..6] == 'http://'
          match
        elsif src =~ %r{/\w\w/.*?(\d+)(_\w+|)\.\w+(\?\d+|)}
          # already parsed
          zip, mode, stamp = $1, $2, $3
          if src_node = secure(Node) { Node.find_by_zip(zip) }
            if mode.blank?
              # no cachestamp, we need it
              "url(#{quote}#{helper.send(:data_path, src_node)}#{quote})"
            else
              "url(#{quote}#{helper.send(:data_path, src_node, :mode => mode[1..-1])}#{quote})"
            end
          else
            # ok
            "url(#{quote}#{src}#{quote})"
          end
        else
          if new_src = helper.send(:template_url_for_asset,
              :src          => src,
              :parent       => parent,
              :parse_assets => true )

            "url(#{quote}#{new_src}#{quote})"
          elsif !(src =~ /\.\./) && File.exist?(File.join(SITES_ROOT, current_site.public_path, src))
            "url(#{quote}#{src}?#{File.mtime(File.join(SITES_ROOT, current_site.public_path, src)).to_i}#{quote})"
          else
            errors.add('asset', _('%{asset} not found') % {:asset => src.inspect})
            "url(#{quote}#{src}#{quote})"
          end
        end
      end
    else
      # unknown type
      super
    end
    res
  end

  def file=(file)
    @new_file = file
    self.text = @new_file.read
  end

  def file(format=nil)
    @loaded_file ||= @new_file || StringIO.new(text)
  end

  def filename
    "#{title}.#{ext}"
  end

  # Get the file path defined in attachment.
  def filepath(format=nil)
    nil
  end

  # Return document file size (= version's text size).
  def size(format=nil)
    (text || '').size
  end

  # Parse text and replace absolute urls ('/en/image30.jpg') by their relative value in the current skin ('img/bird.jpg')
  def unparse_assets(text, helper, key)
    if key == 'text' && prop['content_type'] == 'text/css'
      res = text.dup
      # use parent as relative root
      base_path = parent.fullpath

      res.gsub!(/url\(('|")(.*?)\1\)/) do
        if $2[0..6] == 'http://'
          $&
        else
          quote, url   = $1, $2
          if url =~ /\A\/\w\w\/.*?(\d+)(_\w+|)\./
            zip, mode = $1, $2
            if asset = secure(Node) { Node.find_by_zip(zip) }
              if asset.fullpath =~ /\A#{base_path}\/(.+)/
                path = fullpath_as_title($1)
                "url(#{quote}#{path}#{mode}.#{asset.prop['ext']}#{quote})"
              else
                "url(#{quote}/#{asset.fullpath_as_title.map(&:to_filename).join('/')}#{mode}.#{asset.prop['ext']}#{quote})"
              end
            else
              errors.add('asset', '%{zip} not found', :zip => zip)
              "url(#{quote}#{url}#{quote})"
            end
          elsif File.exist?(File.join(SITES_ROOT, current_site.public_path, url.sub(/\?\d+\Z/,'')))
            "url(#{quote}#{url.sub(/\?\d+\Z/,'')}#{quote})"
          else
            # bad format
            errors.add('base', "cannot unparse asset url #{url.inspect}")
            "url(#{quote}#{url}#{quote})"
          end
        end
      end
      res
    else
      super
    end
  end

  # List of keys to export in a zml file. "text" is ignored since it's exported in a separate file.
  def export_keys
    h = super
    h[:zazen].delete('text')
    h
  end

  # List of keys which need transformations
  def parse_keys
    (super + (content_type == 'text/css' ? ['text'] : [])).uniq
  end

  # Do not sweep TextDocument cache in dev mode unless expire_in_dev.
  def sweep_cache
    if visitor.dev_mode? && !current_site.expire_in_dev?
      # Only expire templates built for dev mode
      super(:conditions => ['path like ?', "%/dev_#{visitor.lang}/%"])
    else
      super
    end
  end

  private
    class AssetHelper
      attr_accessor :visitor
      include Zena::Acts::Secure                # secure
      include Zena::Use::Zazen::ViewMethods     # make_image, ...
      include Zena::Use::ZafuTemplates::Common  # template_url_for_asset
      include Zena::Use::Urls::Common           # data_path
    end

    # Overwrite superclass (DocumentContent) behavior
    def valid_file
      return true
    end

    def set_defaults
      super
      self.content_type = 'text/plain' if content_type.blank?
      self.ext          = 'txt'        if ext.blank?
      parse_assets_text_assets
    end

    # Called from Document#set_defaults
    def set_attachment_filename
      # do nothing
    end

    def parse_assets_text_assets
      if can_parse_assets? && prop.text_changed?
        helper = AssetHelper.new
        helper.visitor = visitor
        self.text = parse_assets(self.text, helper, 'text')
      end
    end
end
