=begin rdoc
A reference represents some information that the site mirrors. It is not displayed in the page hierarchy nor in some date related view (calendar,blog) but is usually found by doing a search or by its links. For example you could create a Tag called 'clients' and link every contact that is a client to this tag. Going to this tag you would have the list of clients.

A reference can only be created in a Section. It can be linked from anywhere.

=== subclasses

Contact:: every User has a unique contact page to store address, name, phone, etc.
Book::    used to add a bibliography and/or by the 'Reading' class (not implemented yet).

=== links

Default links for Reference are:

reference_for::  nodes for which the current item is a reference.
=end
class Reference < Node
end
