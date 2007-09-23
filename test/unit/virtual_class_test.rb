require File.dirname(__FILE__) + '/../test_helper'

class VirtualClassTest < ZenaTestUnit
  
  def test_virtual_subclasse
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Post', :name => 'Super', :create_group_id =>  groups_id(:public))
    assert !vclass.new_record?
    assert_equal "NNPS", vclass.kpath
  end
  
  def test_node_classes_for_form
    login(:anon)
    # preload models
    [Project, Skin, Note, Image, Template, Contact]
    
    classes_for_form = Node.classes_for_form
    assert classes_for_form.include?(["Node", "Node"])
    assert classes_for_form.include?(["  Page", "Page"])
    assert classes_for_form.include?(["  Note", "Note"])
    assert classes_for_form.include?(["  Reference", "Reference"])
    assert classes_for_form.include?(["    Letter", "Letter"])
  end
  
  def test_note_classes_for_form
    login(:anon)
    # preload models
    [Project, Skin, Note, Image, Template, Contact]
    
    classes_for_form = Note.classes_for_form
    assert classes_for_form.include?(["Note", "Note"])
    assert classes_for_form.include?(["  Letter", "Letter"])
    assert classes_for_form.include?(["  Post", "Post"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Node")
    assert !classes_for_form.include?("Page")
    assert !classes_for_form.include?("Reference")
  end
  
  def test_post_classes_for_form
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Post', :name => 'Super', :create_group_id =>  groups_id(:public))
    assert !vclass.new_record?
    
    login(:anon)
    
    classes_for_form = Node.get_class('Post').classes_for_form
    assert classes_for_form.include?(["Post", "Post"])
    assert classes_for_form.include?(["  Super", "Super"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Node")
    assert !classes_for_form.include?("Note")
    assert !classes_for_form.include?("Letter")
    assert !classes_for_form.include?("Page")
    assert !classes_for_form.include?("Reference")
  end
  
  def test_post_classes_for_form_opt
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Post', :name => 'Super', :create_group_id =>  groups_id(:public))
    assert !vclass.new_record?
    
    login(:anon)
    
    classes_for_form = Node.classes_for_form(:class => 'Post')
    assert classes_for_form.include?(["Post", "Post"])
    assert classes_for_form.include?(["  Super", "Super"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Node")
    assert !classes_for_form.include?("Note")
    assert !classes_for_form.include?("Letter")
    assert !classes_for_form.include?("Page")
    assert !classes_for_form.include?("Reference")
  end
  
  def test_post_classes_for_form_opt
    # add a sub class
    login(:lion)
    vclass = VirtualClass.create(:superclass => 'Post', :name => 'Super', :create_group_id =>  groups_id(:public))
    assert !vclass.new_record?
    
    login(:anon)
    
    classes_for_form = Node.classes_for_form(:class => 'Post', :without=>'Super')
    assert classes_for_form.include?(["Post", "Post"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Node")
    assert !classes_for_form.include?("Note")
    assert !classes_for_form.include?("Letter")
    assert !classes_for_form.include?("Page")
    assert !classes_for_form.include?("Reference")
    assert !classes_for_form.include?("Super")
  end
  
  def test_node_classes_for_form_except
    login(:anon)
    # preload models
    [Project, Skin, Note, Image, Template, Contact]
    
    classes_for_form = Node.classes_for_form(:without => 'Letter')
    assert classes_for_form.include?(["Node", "Node"])
    assert classes_for_form.include?(["  Page", "Page"])
    assert classes_for_form.include?(["  Note", "Note"])
    assert classes_for_form.include?(["  Reference", "Reference"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Letter")
    
    classes_for_form = Node.classes_for_form(:without => 'Letter,Reference,Truc')
    assert classes_for_form.include?(["Node", "Node"])
    assert classes_for_form.include?(["  Page", "Page"])
    assert classes_for_form.include?(["  Note", "Note"])
    classes_for_form.map!{|k,c| c}
    assert !classes_for_form.include?("Letter")
    assert !classes_for_form.include?("Reference")
  end
  
  def test_node_classes_read_group
    login(:anon)
    classes_for_form = Node.classes_for_form
    assert !classes_for_form.include?(["    Tracker", "Tracker"])
    login(:lion)
    classes_for_form = Node.classes_for_form
    assert classes_for_form.include?(["    Tracker", "Tracker"])
  end
  
  def test_vkind_of
    letter = secure(Node) { nodes(:letter) }
    assert letter.vkind_of?('Letter')
    assert letter.vkind_of?('Note')
    assert letter.kpath_match?('NN')
    assert letter.kpath_match?('NNL')
  end
  
  def test_create_letter
    login(:ant)
    assert node = secure(Node) { Node.create_node(:v_title => 'my letter', :class => 'Letter', :parent_id => nodes_zip(:cleanWater)) }
    assert_kind_of Note, node
    assert !node.new_record?
    assert node.virtual_class
    assert_equal virtual_classes_id(:letter), node.vclass_id
    assert_equal 'Letter', node.klass
    assert node.vkind_of?('Letter')
    assert_equal "NNL", node[:kpath]
  end
  
  def test_new
    assert false, "TODO"
  end
  
  def test_relation
    login(:ant)
    node = secure(Node) { nodes(:zena) }
    assert letters = node.find(:all,'letters')
    assert_equal 1, letters.size
    assert letters[0].vkind_of?('Letter')
    assert_kind_of Note, letters[0]
  end
  
  def test_superclass
    assert_equal Note, virtual_classes(:post).superclass
    assert_equal Note, virtual_classes(:letter).superclass
    assert_equal Page, virtual_classes(:tracker).superclass
  end
end
