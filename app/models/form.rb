# TODO: integration test and doc for FormSeizure
class Form < Page
  before_create :set_dgroup
  
  def set_dgroup
    self[:dgroup_id] = self[:pgroup_id]
  end
  
  def text
    "<div class='fada'>\n" + render(super) + "\n</div>\n"
  end
  
  def summary
    "<div class='fada'>\n" + render(super) + "\n</div>\n"
  end
  
  def set_vars(vars)
    @vars = vars
  end
  
  def new_seizure(params)
    params[:form_id] = self[:id]
    params[:user_id] = visitor.id
    FormSeizure.create(params)
  end

  def render(txt)
    parse(txt).render( :on_edit=>self, :data=>data, :on_form=>self, :var=>@vars )
  end
  
  def parse(txt)
    Zena::Fada::Parser.new(txt)
  end
  
  def data
    d = FormSeizure.find_seizures(self[:id], nil, visitor_groups)
    d = [{}] if d == []
    d
  end
  
  def on_form(op)
    op << "<form action='/z/form/create/#{self[:id]}' method='post' id='form_#{self[:id]}'>"
    op << op.render_block << "</form>"
  end
  
  # register new callbacks for edit context
  def on_edit(op)
    on_value = Proc.new do |op|
      
      #if @context[:edit] && seizure[:user_id] == visitor.id && data.size == 1
      #  val_id  = seizure.id_for[:key]
      #  "<#{table ? 'td' : 'div'} id='line_#{val_id}' class='line_form'>" + 
      #  link_to_remote("#{value}", 
      #      :update=>"line_#{val_id}", 
      #      :url=>"/form/edit/#{val_id}",
      #      :complete=>'$("line_value").focus();$("line_value").select()') +
      #  "</#{table ? 'td' : 'div'}>"
      #else
      begin
        # when redering on_value, in case we find a block, keep on_value behavior inside the protected block
        op << "edit:#{op.on_value(:keep=>:on_value)}"
      rescue
        op << "edit:?"
      end
    end
    op[:on_value] = on_value
  end
end