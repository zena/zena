require 'test_helper'

class MarkupTest < Test::Unit::TestCase
  include RubyLess
  safe_method :day => {:class => String, :method => %q{Time.now.strftime('%A')}}
  Markup = Zafu::Markup

  context 'Parsing parameters' do
    should 'retrieve values escaped with single quotes' do
      h = {:class => 'worker', :style => 'tired'}
      assert_equal h, Markup.parse_params("class='worker' style='tired'")
    end

    should 'retrieve values escaped with double quotes' do
      h = {:class => 'worker', :style => 'tired'}
      assert_equal h, Markup.parse_params('class="worker" style="tired"')
    end

    should 'retrieve values escaped with mixed quotes' do
      h = {:class => 'worker', :style => 'tired'}
      assert_equal h, Markup.parse_params('class=\'worker\' style="tired"')
    end

    should 'properly handle escaped single quotes' do
      h = {:class => "that's nice", :style => 'tired'}
      assert_equal h, Markup.parse_params("class='that\\\'s nice' style='tired'")
    end

    should 'properly handle escaped double quotes' do
      h = {:class => '30"', :style => 'tired'}
      assert_equal h, Markup.parse_params('class="30\\"" style="tired"')
    end
  end

  context 'Setting parameters' do
    setup do
      @markup = Markup.new('p')
    end

    should 'parse params if the parameters are provided as a string' do
      @markup.params = "class='shiny' id='slogan'"
      h = {:class => 'shiny', :id => 'slogan'}
      assert_equal h, @markup.params
    end

    should 'set params if the parameters are provided as a hash' do
      @markup.params = {:class => 'shiny', :style => 'good'}
      h = {:class => 'shiny', :style => 'good'}
      assert_equal h, @markup.params
    end

    should 'respond to has_param' do
      @markup.params     = {:class => 'one', :x => 'y'}
      @markup.dyn_params = {:y => 'z'}
      assert @markup.has_param?(:x)
      assert @markup.has_param?(:y)
      assert !@markup.has_param?(:z)
    end
  end

  context 'Stealing html params' do
    subject do
      Markup.new('p')
    end

    should 'transfer common html params' do
      base = {:class => 'blue', :name => 'sprout', :id => 'front_cover', :style => 'padding:5px;', :attr => 'title'}
      subject.steal_html_params_from(base)
      new_base = {:name => 'sprout', :attr => 'title'}
      markup_params = {:class => 'blue', :id => 'front_cover', :style => 'padding:5px;'}
      assert_equal new_base, base
      assert_equal markup_params, subject.params
    end

    context 'on a link' do
      subject do
        Markup.new('link')
      end

      should 'transfer common html params' do
        base = {:rel => 'rel', :type => 'type', :class => 'blue', :name => 'sprout', :id => 'front_cover', :style => 'padding:5px;', :attr => 'title'}
        subject.steal_html_params_from(base)
        new_base = {:name => 'sprout', :attr => 'title'}
        markup_params = {:type=>"type", :rel=>"rel", :id => 'front_cover', :class => 'blue', :style => 'padding:5px;'}
        assert_equal new_base, base
        assert_equal markup_params, subject.params
      end
    end
  end

  context 'Defining the dom id' do
    setup do
      @markup = Markup.new('p')
      @markup.params[:id] = 'foobar'
      @markup.dyn_params[:id] = 'foobar'
      @markup.set_id('<%= @node.zip %>')
    end

    should 'remove any predifined id' do
      assert_nil @markup.params[:id]
    end

    should 'write id in the dynamic params' do
      assert_equal '<%= @node.zip %>', @markup.dyn_params[:id]
    end
  end

  context 'Setting a dynamic param' do
    setup do
      @markup = Markup.new('p')
      @markup.params[:foo] = 'one'
      @markup.set_dyn_params(:foo => '<%= @node.two %>')
    end

    should 'clear a static param with same key' do
      assert_nil @markup.params[:foo]
      assert_equal '<%= @node.two %>', @markup.dyn_params[:foo]
    end
  end

  context 'Setting a static param' do
    setup do
      @markup = Markup.new('p')
      @markup.dyn_params[:foo] = '<%= @node.two %>'
      @markup.set_params(:foo => 'one')
    end

    should 'clear a dynamic param with same key' do
      assert_nil @markup.dyn_params[:foo]
      assert_equal 'one', @markup.params[:foo]
    end
  end


  context 'Appending a static param' do
    context 'on a static param' do
      setup do
        @markup = Markup.new('p')
        @markup.set_params(:class => 'simple')
      end

      should 'append param in the static params' do
        @markup.append_param(:class, 'mind')
        assert_equal 'simple mind', @markup.params[:class]
      end
    end

    context 'on a dynamic param' do
      setup do
        @markup = Markup.new('p')
        @markup.set_dyn_params(:class => '<%= @foo %>')
      end

      should 'append param in the dynamic params' do
        @markup.append_param(:class, 'bar')
        assert_equal '<%= @foo %> bar', @markup.dyn_params[:class]
      end
    end

    context 'on an empty param' do
      setup do
        @markup = Markup.new('p')
      end

      should 'set param in the static params' do
        @markup.append_param(:class, 'bar')
        assert_equal 'bar', @markup.params[:class]
      end
    end
  end

  context 'Prepending a static param' do
    context 'on a static param' do
      setup do
        @markup = Markup.new('p')
        @markup.set_params(:class => 'simple')
      end

      should 'prepend param in the static params' do
        @markup.prepend_param(:class, 'super')
        assert_equal 'super simple', @markup.params[:class]
      end
    end

    context 'on a dynamic param' do
      setup do
        @markup = Markup.new('p')
        @markup.set_dyn_params(:class => '<%= @fu %>')
      end

      should 'prepend param in the dynamic params' do
        @markup.prepend_param(:class, 'to')
        assert_equal 'to <%= @fu %>', @markup.dyn_params[:class]
      end
    end

    context 'on an empty param' do
      setup do
        @markup = Markup.new('p')
      end

      should 'set param in the static params' do
        @markup.prepend_param(:class, 'bar')
        assert_equal 'bar', @markup.params[:class]
      end
    end
  end

  context 'Appending a dynamic param' do
    context 'on a static param' do
      setup do
        @markup = Markup.new('p')
        @markup.set_params(:class => 'simple')
      end

      should 'copy the static param in the dynamic params' do
        @markup.append_dyn_param(:class, '<%= @mind %>')
        assert_equal 'simple <%= @mind %>', @markup.dyn_params[:class]
      end
    end

    context 'on a dynamic param' do
      setup do
        @markup = Markup.new('p')
        @markup.set_dyn_params(:class => '<%= @foo %>')
      end

      should 'append param in the dynamic params' do
        @markup.append_dyn_param(:class, '<%= @bar %>')
        assert_equal '<%= @foo %> <%= @bar %>', @markup.dyn_params[:class]
      end

      should 'append param without spacer if conditional' do
        @markup.append_dyn_param(:class, '<%= @bar %>', true)
        assert_equal '<%= @foo %><%= @bar %>', @markup.dyn_params[:class]
      end
    end

    context 'on an empty param' do
      setup do
        @markup = Markup.new('p')
      end

      should 'set param in the dynamic params' do
        @markup.append_dyn_param(:class, '<%= @bar %>')
        assert_equal '<%= @bar %>', @markup.dyn_params[:class]
      end
    end
  end

  context 'Prepending a dynamic param' do
    context 'on a static param' do
      setup do
        @markup = Markup.new('p')
        @markup.set_params(:class => 'fu')
      end

      should 'copy the static param in the dynamic params' do
        @markup.prepend_dyn_param(:class, '<%= @to %>')
        assert_equal '<%= @to %> fu', @markup.dyn_params[:class]
      end
    end

    context 'on a dynamic param' do
      setup do
        @markup = Markup.new('p')
        @markup.set_dyn_params(:class => '<%= @fu %>')
      end

      should 'prepend param in the dynamic params' do
        @markup.prepend_dyn_param(:class, '<%= @to %>')
        assert_equal '<%= @to %> <%= @fu %>', @markup.dyn_params[:class]
      end

      should 'prepend param without spacer if conditional' do
        @markup.prepend_dyn_param(:class, '<%= @to %>', true)
        assert_equal '<%= @to %><%= @fu %>', @markup.dyn_params[:class]
      end
    end

    context 'on an empty param' do
      setup do
        @markup = Markup.new('p')
      end

      should 'set param in the dynamic params' do
        @markup.prepend_dyn_param(:class, '<%= @bar %>')
        assert_equal '<%= @bar %>', @markup.dyn_params[:class]
      end
    end
  end
  
  context 'To string' do
    subject do
      Markup.new('img', :src => '/foo/bar.png')
    end
    
    should 'render' do
      assert_equal "<img src='/foo/bar.png'/>", subject.to_s
    end
  end

  context 'Wrapping some text' do
    setup do
      @text = 'Alice: It would be so nice if something made sense for a change.'
      @markup = Markup.new('p')
      @markup.params[:class] = 'quote'
      @markup.params[:style] = 'padding:3px; border:1px solid red;'
    end

    should 'add the markup tag around the text' do
      assert_equal "<p class='quote' style='padding:3px; border:1px solid red;'>#{@text}</p>", @markup.wrap(@text)
    end

    should 'add the appended params inside the tag' do
      @markup.append_attribute("<%= anything %>")
      assert_equal "<p class='quote' style='padding:3px; border:1px solid red;'<%= anything %>>#{@text}</p>", @markup.wrap(@text)
    end

    should 'not wrap twice if called twice' do
      assert_equal "<p class='quote' style='padding:3px; border:1px solid red;'>#{@text}</p>", @markup.wrap(@markup.wrap(@text))
    end

    should 'display static params before dynamic and keep them ordered' do
      @markup.set_dyn_params(:foo => '<%= @bar %>')
      @markup.set_params(:baz => 'buzz')
      assert_equal "<p class='quote' style='padding:3px; border:1px solid red;' baz='buzz' foo='<%= @bar %>'>foo</p>", @markup.wrap('foo')
    end

    should 'insert pre_wrap content' do
      @markup.pre_wrap[:foo] = 'FOO'
      assert_equal %q{<p class='quote' style='padding:3px; border:1px solid red;'>FOOcontent</p>}, @markup.wrap('content')
    end
  end

  context 'Compiling params' do
    setup do
      @markup = Markup.new('p')
      @markup.params = %q{class='one #{day}' id='foobar' name='#{day}'}
    end

    context 'with compile_params' do
      setup do
        @markup.compile_params(self)
      end

      should 'translate dynamic params into ERB by using RubyLess' do
        assert_equal %q{<%= "one #{Time.now.strftime('%A')}" %>}, @markup.dyn_params[:class]
      end

      should 'translate without string on single dynamic content' do
        assert_equal %q{<%= Time.now.strftime('%A') %>}, @markup.dyn_params[:name]
      end
    end
  end

  context 'Duplicating a markup' do
    context 'and changing params' do
      setup do
        @markup = Markup.new('p')
        @markup.params[:class]  = 'one'
        @duplicate = @markup.dup
      end

      should 'not propagate params changes to original' do
        @duplicate.params[:class] = 'two'
        assert_equal "<p class='one'>one</p>", @markup.wrap('one')
      end

      should 'not propagate params changes to duplicate' do
        @markup.params[:class] = 'two'
        assert_equal "<p class='one'>one</p>", @duplicate.wrap('one')
      end

      should 'not propagate appended params to duplicate' do
        @markup.append_param(:class, 'drop')
        assert_equal "<p class='one'>one</p>", @duplicate.wrap('one')
      end

      should 'not propagate dyn_params changes to original' do
        @markup.append_dyn_param(:class, 'two')
        assert_equal "<p class='one'>one</p>", @duplicate.wrap('one')
      end

      should 'not propagate dyn_params changes to duplicate' do
        @duplicate.append_dyn_param(:class, 'two')
        assert_equal "<p class='one'>one</p>", @markup.wrap('one')
      end

      should 'not propagate pre_wrap changes to duplicate' do
        @markup.pre_wrap[:drop] = 'no bombs'
        @duplicate = @markup.dup
        @duplicate.pre_wrap[:drop] = 'ego'
        assert_equal "<p class='one'>no bombs</p>", @markup.wrap('')
      end
    end

    context 'and wrapping' do
      setup do
        @markup = Markup.new('p')
        @duplicate = @markup.dup
      end

      should 'not propagate done to duplicate' do
        @markup.wrap('')
        assert_equal '<p>one</p>', @duplicate.wrap('one')
      end
    end
  end # Duplicating a markup
end




