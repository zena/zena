=begin rdoc
Definitions:

* master template: used to render a node. It is used depending on it's 'target_klass' filter.
* helper template: included into another template.

Render ---> Master template --include--> helper template --include--> ...

For master templates, the title is build from the different filters (target_klass, mode, format):

Klass-mode-format. Examples: Node-index, Node--xml, Project-info. Note how the format is omitted when it is 'html'.

Other templates have a title built from the given name, just like any other node.

=end
class Template < TextDocument
  MODE_FORMAT_FROM_TITLE = /^([A-Z][a-zA-Z]+?)(-(([a-zA-Z_\+]*)(-([a-zA-Z_]+)|))|)(\.|\Z)/
  property do |p|
    p.string  'target_klass'
    p.string  'format'
    p.string  'mode'
    p.string  'tkpath'

    p.index(IdxTemplate) do |record|
      {
        'format'    => record.format,
        'mode'      => record.mode,
        'tkpath'    => record.tkpath,
        'skin_id'   => record[:section_id],
      }
    end

    safe_property :tkpath, :mode, :target_klass, :format
  end

  attr_protected    :tkpath
  before_validation :rebuild_tkpath
  validate          :validate_section, :validate_target_klass

  # Class Methods
  class << self
    def accept_content_type?(content_type)
      content_type =~ /text\/(zafu)/
    end
  end # Class Methods

  def filename
    "#{title}.#{ext}"
  end

  def skin
    @skin ||= secure(Skin) { Skin.find(skin_id) }
  end
  
  def rebuild_tkpath(rebuild_tklass = nil)
    if target_klass
      # this is a master template (found when choosing the template for rendering)
      if klass = rebuild_tklass
        # rebuilding index
        self.target_klass = klass.name
        self.tkpath       = klass.kpath
        self.title = title_from_mode_and_format
      elsif klass = VirtualClass[target_klass]
        self.tkpath = klass.kpath
      end
    else
      self.tkpath = nil
    end
  end

  private

    def set_defaults
      self.mode  = nil if mode.blank?
      self.target_klass = nil if target_klass.blank?
      super

      # Force template extension to zafu
      self.ext = 'zafu'

      # Force template content-type to 'text/zafu'
      self.content_type = 'text/zafu'

      if prop.title_changed?
        if title =~ MODE_FORMAT_FROM_TITLE
          # title changed force  update
          self.target_klass  = $1            unless prop.target_klass_changed?
          self.mode   = ($4 || '')           unless prop.mode_changed?
          self.format = ($6 || 'html')       unless prop.format_changed?
        else
          # title set but it is not a master template name
          self.target_klass  = nil
          self.mode   = nil
          self.format = nil
        end
      end

      if version.edited?
         self.mode = mode.gsub(/[^a-zA-Z\+]/, '') if mode

        if !target_klass.blank?
          # update title
          self.format = 'html' if format.blank?
          self.title = title_from_mode_and_format

          if text.blank? && format == 'html' && mode != '+edit'
            # set a default text

            if target_klass == 'Node'
              self.text = <<END_TXT
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns='http://www.w3.org/1999/xhtml' do='void' lang='\#{v.lang}' xml:lang='en'>
<head do='void' name='head'>
  <title do='title_for_layout' do='show' attr='title' name='page_title'>page title</title>
  <!-- link href='favicon.png' rel='shortcut icon' type='image/png' / -->
  <meta http-equiv='Content-type' content='text/html; charset=utf-8' />
  <r:void name='stylesheets'>
    <r:stylesheets/>
    <link href='style.css' rel='Stylesheet' type='text/css'/>
  </r:void>

  <r:javascripts/>
  <r:uses_datebox/>
</head>
<body>



</body>
</html>
END_TXT
            else
              self.text = "<r:include template='Node'/>\n"
            end
          end
        end
      end
    end

    def title_from_mode_and_format(opts={})
      opts[:format]  ||= format
      opts[:mode  ]  ||= mode
      opts[:target_klass ]  ||= target_klass
      format = opts[:format] == 'html' ? '' : "-#{opts[:format]}"
      mode   = (!opts[:mode].blank? || format != '') ? "-#{opts[:mode]}" : ''
      "#{opts[:target_klass]}#{mode}#{format}"
    end

    def validate_section
      errors.add('parent_id', 'invalid (section is not a Skin)') unless section.kind_of?(Skin)
    end

    def validate_target_klass
      if target_klass
        errors.add('format', "can't be blank") unless format
        errors.add('target_klass', 'invalid') unless VirtualClass[target_klass]
      end
    end
end
