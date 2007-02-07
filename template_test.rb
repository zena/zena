=begin
content =<<-ENDTXT
<ul>
  <z:documents>
  <li><z:icon/><z:name/></li>
  </z:documents>
</ul>
ENDTXT
==>
result =<<-ENDTXT
<ul>
  <% @node.documents.each do |document| -%>
  <li><%= @node.icon ? icon.img_tag('pv') : '' %><%= document.name %></li>
  <% end -%>
</ul>
ENDTXT

rules :
=end

class Zafu
  def initialize
    @context = {}
    @content = ""
  end
  
  def expand(text = @context[:inner])
    # scan to first opening <z:...> tag
    rest = text
    while (rest != "") do
      if rest =~ /(.*?)<z:([^>]+)>(.*)/m
        out $1
        rest = $3
        tag  = $2
        if tag[-1..-1] == '/'
          sym = tag[0..-2].to_sym
        elsif rest =~ /(.*)<\/z:#{tag}>(.*)/m
          sym   = tag.to_sym
          inner = $1
          rest  = $2
        else
          raise Exception.new
        end
        call_with(sym, nil, :inner=>inner)
      else
        out rest
        rest = ""
      end
    end
    @content
  end
  
  def expand_with(new_context)
    # backup context
    context = @context.dup
    # create new context
    @context.merge!(new_context)
    expand
    # restore context
    @context = context
  end
  
  def call_with(sym, params, new_context)
    # backup context
    context = @context.dup
    # create new context
    @context.merge!(new_context)
    res = self.send(sym,params)
    out(res) unless res.nil?
    # restore context
    @context = context
  end
  
  def out(str)
    @content += str
    nil
  end
    

  def documents(params)
    out "<% if #{var_inc} = #{node}.documents -%>"
    expand_with(:list=>var)
    out "<% end -%>"
  end
  
  def each(params)
    out "<% #{list}.each do |#{var_inc}|"
    expand_with(:node=>var)
    out "<% end -%>"
  end

  def name(params)
    "<%= #{node}.name %>"
  end
  
  def count(params)
    "<%= #{list}.count %>"
  end
  
  private
  def node
    @context[:node] || '@node'
  end
  
  def list
    @context[:list]
  end
  
  def var_inc
    @var_counter ||= 0
    @var_counter += 1
    var
  end
  
  def var
    "var#{@var_counter}"
  end
end

res = Zafu.new.expand <<-ENDTXT
<ul>
  <z:documents>
  <z:each>
  <li><z:name/></li>
  </z:each>
  there are <z:count/> children
  </z:documents>
</ul>
ENDTXT

puts res