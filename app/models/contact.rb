=begin
=== Contact
Every address in Zena is a Contact except 'anon' and 'su'.
=end
class Contact < Page
  belongs_to :address, :dependent=>:destroy
  # Participant :
  # class_name with 'Item' is a hack for recursion problems
  # maybe use 'through' when things get more complicated...
  has_and_belongs_to_many :projects
end
