class Participation < ActiveRecord::Base
  belongs_to            :site
  belongs_to            :user
  belongs_to            :contact, :dependent => :destroy
  validates_presence_of :user_id
  validates_presence_of :site_id
  before_create         :create_contact
  
  alias o_contact contact
  
  def contact
    @contact ||= secure(Contact) { o_contact }
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  # Secure raises an AccessViolation when 'site_id=' is called. It is allowed here !
  def site_id=(i)
    self[:site_id] = i
  end
  
  private
    def valid_participation
      errors.add('base' , 'record not secured') unless @visitor
    end
    
    def create_contact
      return unless visitor.site[:root_id] # do not try to create a contact if the root node is not created yet
      
      @contact = secure(Contact) { Contact.new( 
        # owner is the user except for anonymous and super user.
        # TODO: not sure this is a good idea...
        :user_id       => (self[:id] == current_site[:anon_id] || self[:id] == current_site[:su_id]) ? visitor[:id] : self[:id],
        :v_title       => (user.name.blank? || user.first_name.blank?) ? user.login : user.fullname,
        :c_first_name  => user.first_name,
        :c_name        => (user.name || user.login ),
        :c_email       => user.email
      )}
      @contact[:parent_id] = current_site[:root_id]
      unless @contact.save
        # What do we do with this error ?
        raise Zena::InvalidRecord, "Could not create contact node for user #{user_id} in site #{site_id} (#{@contact.errors.map{|k,v| [k,v]}.join(', ')})"
      end
      unless @contact.publish
        raise Zena::InvalidRecord, "Could not publish contact node for user #{user_id} in site #{site_id} (#{@contact.errors.map{|k,v| [k,v]}.join(', ')})"
      end
      self[:contact_id] = @contact[:id]
      
      # FIXME: do we want this ?
      # User.connection.execute "UPDATE nodes SET user_id = #{self[:id]} WHERE id = #{@contact[:id]}"
    end
end
