require 'versions'

class Attachment < Versions::SharedAttachment

  before_save :save_visitor_id, :save_site_id

  def filepath(format=nil)
    mode   = format ? (format[:size] == :keep ? 'full' : format[:name]) : 'full'
    "#{SITES_ROOT}#{current_site.data_path}/#{mode}/#{super()}"
  end

  private
    def save_visitor_id
      self['user_id'] = visitor.id
    end

    def save_site_id
      self['site_id'] = current_site.id
    end

end