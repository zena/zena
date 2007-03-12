class Site < ActiveRecord::Base
  
  # Return path for static/cached content served by proxy. If the 'public_path' setting was left to NULL,
  # the default is used : RAILS_ROOT/sites/_host_/public
  def public_path
    self[:public_path] || "#{RAILS_ROOT}/sites/#{self[:host]}/public"
  end
  
  
  # Return path for documents data. If 'data_path' setting was left to NULL,
  # the default is used : RAILS_ROOT/sites/_host_/data
  def data_path
    self[:data_path] || "#{RAILS_ROOT}/sites/#{self[:host]}/data"
  end
  
  # Anonymous user, the one used by anonymous visitors to visit the public part
  # of the site.
  def anon
    @anon ||= User.find(self[:anon_id])
  end
  
  # Super user: has extended priviledges on the data (has access to private data)
  def su
    @su ||= User.find(self[:su_id])
  end
end
