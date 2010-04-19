=begin rdoc
Definitions:

* master template: used to render a node. It is used depending on it's 'target_klass' filter.
* helper template: included into another template.

Render ---> Master template --include--> helper template --include--> ...

For master templates, the name is build from the different filters (target_klass, mode, format):

Klass-mode-format. Examples: Node-index, Node--xml, Project-info. Note how the format is omitted when it is 'html'.

Other templates have a name built from the given name, just like any other node.

=end
class Template < TextDocument

  property do |p|
    p.string  'target_klass'
    p.string  'format'
    p.string  'mode'
    p.string  'tkpath'

    p.index(TemplateIndex) do |record|
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
  validate          :validate_section, :validate_target_klass
  before_validation :template_content_before_validation

  # Class Methods
  class << self
    def accept_content_type?(content_type)
      content_type =~ /text\/(html|zafu)/
    end
  end # Class Methods

  # Force template content-type to 'text/zafu'
  def content_type
    "text/zafu"
  end

  # Force template extension to zafu
  def ext
    'zafu'
  end

  # Ignore ext assignation
  def ext=(ext)
    'zafu'
  end

  def filename
    "#{name}.zafu"
  end

  def skin
    @skin ||= secure(Skin) { Skin.find(prop['skin_id']) }
  end

  private

    def set_defaults
      super

      if name_changed?
        if name =~ /^([A-Z][a-zA-Z]+?)(-(([a-zA-Z_\+]*)(-([a-zA-Z_]+)|))|)(\.|\Z)/
          # name/title changed force  update
          prop['target_klass']  = $1            unless prop.target_klass_changed?
          prop['mode']   = ($4 || '').url_name  unless prop.mode_changed?
          prop['format'] = ($6 || 'html')       unless prop.format_changed?
        else
          # name set but it is not a master template name
          prop['target_klass']  = nil
          prop['mode']   = nil
          prop['format'] = nil
        end
      end

      if version.changed? || self.properties.changed? || self.new_record?
         prop['mode'] = prop['mode'].url_name if prop['mode']

        if !prop['target_klass'].blank?
          # update name
          prop['format'] = 'html' if prop['format'].blank?
          self[:name] = name_from_content
          version.title = self[:name]

          if version.text.blank? && prop['format'] == 'html' && prop['mode'] != '+edit'
            # set a default text

            if prop['target_klass'] == 'Node'
              version.text = <<END_TXT
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" do='void' lang="en" set_lang='[v_lang]' xml:lang='en'>
<head do='void' name='head'>
  <title do='title_for_layout' do='show' attr='title' name='page_title'>page title</title>
  <!-- link href='favicon.png' rel='shortcut icon' type='image/png' / -->
  <meta http-equiv="Content-type" content="text/html; charset=utf-8" />
  <r:void name='stylesheets'>
    <r:stylesheets list='reset,zena,code'/>
    <link href="style.css" rel="Stylesheet" type="text/css"/>
  </r:void>

  <r:javascripts list='prototype,effects,zena'/>
  <r:uses_datebox/>
</head>
<body>



</body>
</html>
END_TXT
            else
              version.text = "<r:include template='Node'/>\n"
            end
          end
        end
      end
    end

    def name_from_content(opts={})
      opts[:format]  ||= prop['format']
      opts[:mode  ]  ||= prop['mode']
      opts[:target_klass ]  ||= prop['target_klass']
      format = opts[:format] == 'html' ? '' : "-#{opts[:format]}"
      mode   = (!opts[:mode].blank? || format != '') ? "-#{opts[:mode]}" : ''
      "#{opts[:target_klass]}#{mode}#{format}"
    end

    def validate_section
      errors.add('parent_id', 'invalid (section is not a Skin)') unless section.kind_of?(Skin)
    end

    def validate_target_klass
      if prop.target_klass_changed? && prop['target_klass']
        errors.add('format', "can't be blank") unless prop['format']
        # this is a master template (found when choosing the template for rendering)
        if target_klass = Node.get_class(prop['target_klass'])
          prop['tkpath'] = target_klass.kpath
        else
          errors.add('target_klass', 'invalid')
        end
      end
    end

    def template_content_before_validation
      prop['mode']  = nil if prop['mode' ].blank?
      prop['target_klass'] = nil if prop['target_klass'].blank?
      unless prop['target_klass']
        # this template is not meant to be accessed directly (partial used for inclusion)
        prop['tkpath'] = nil
        prop['mode']   = nil
        prop['format'] = nil
      end
    end
end
