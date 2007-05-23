class Participation < ActiveRecord::Base
  belongs_to            :sites
  belongs_to            :users
  belongs_to            :contact, :dependant => :destroy
  validates_presence_of :user_id
  validates_presence_of :site_id
  before_create         :create_contact
  
  def contact
    @contact ||= secure(Contact) { Contact.find(self[:contact_id]) }
  rescue ActiveRecord::RecordNotFound
    nil
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
        :user_id       => (self[:id] == visitor_site[:anon_id] || self[:id] == visitor_site[:su_id]) ? visitor[:id] : self[:id],
        :v_title       => (name.blank? || first_name.blank?) ? login : fullname,
        :c_first_name  => first_name,
        :c_name        => (name || login ),
        :c_email       => email
      )}
      @contact[:parent_id] = visitor.site[:root_id]
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
