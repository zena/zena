# Allison RDoc template
# Copyright 2006 Cloudburst LLC

class String
  # fuck this stupid rdoc templater system
  def if_exists (item = nil)
    unless item
      self unless self =~ /(%(\w+)%)/
      "\nIF:#{$2}\n#{self}\nENDIF:#{$2}\n"
    else
      "\nIF:#{item}\n#{self}\nENDIF:#{item}\n"
    end
  end
  def loop(item)
    "\nSTART:#{item}\n#{self}\nEND:#{item}\n"
  end
end

module RDoc
  module Page

    puts "Invoking Allison template..."

    require 'pathname'
    CACHE_DIR = Pathname.new(__FILE__).dirname.to_s + "/cache"

    begin
      require 'rubygems'
      require_gem 'markaby', '>= 0.5' # how come this isn't activate_gem(), since that's what it does?
      require 'markaby'
      require 'base64'

      module Allison
        # markaby page says markaby is better in its own module...

        URL = "http://blog.evanweaver.com/articles/2006/06/02/allison"
        IMGPATH = 'allison.gif'

        FONTS = METHOD_LIST = SRC_PAGE = FILE_PAGE = CLASS_PAGE = ""

        FR_INDEX_BODY = "!INCLUDE!" # who knows

        STYLE, JAVASCRIPT = ["css", "js"].map do |extension|
          File.open(File.dirname(__FILE__) + "/allison.#{extension}").read
        end

        puts "Compiling XHTML..."

        INDEX = Markaby::Builder.new.xhtml_strict do
          head do
            title '%title%'
            link :rel => 'stylesheet', :type => 'text/css', :href => 'rdoc-style.css', :media => 'screen'
            tag! :meta, 'http-equiv' => 'refresh', 'content' => '0;url=%initial_page%'
          end
          body do
            div.container! do
              div.header! do
                span.title! do
                  h1 "Zena Documentation"
                end
              end
              div.clear {}
              div.redirect! do
                a :href => '%initial_page%' do
                  h1 "Redirect"
                end
              end
            end
            p.allison! do
               self << 'template adapted from '
               a 'Allison', :href => URL
            end
          end
        end.to_s

        FILE_INDEX = METHOD_INDEX = CLASS_INDEX = Markaby::Builder.new.capture do
          a :href => '%href%' do
            self << '%name%'
            br
          end
        end.loop('entries')

        BODY = Markaby::Builder.new.xhtml_strict do
          head do
            title "%title%"
            link :rel => 'stylesheet', :type => 'text/css', :href => '%style_url%', :media => 'screen'
            script :type => 'text/javascript' do
              JAVASCRIPT
            end
          end
          body do
              div.header! do
                p {'%full_path%'.if_exists}
                span do
                  h1.title! '%title%'.if_exists
                end
                self << "!INCLUDE!" # always empty
              end
              table.container! do
              self << tr do
                td.left! do
                  self << (div.navigation.dark.top.child_of! do
                    # death to you, horrible templater >:(
                    h3 "Child of"
                    self << "<span>\n#{"<a href='%par_url%'>".if_exists}%parent%#{"</a>".if_exists('par_url')}</span>"
                  end).if_exists('parent')

                  self << div.navigation.dark.top.defined_in! do
                    h3('Defined in')
                    self << a('%full_path%', :href => '%full_path_url%').if_exists.loop('infiles')
                  end.if_exists('infiles')

                  ['includes', 'requires', 'methods'].each do |item|
                    self << div.navigation.top(:id => item) do
                      self << h3(item.capitalize)
                      self << "<span class='bpink'>\n#{"<a href='%aref%'>".if_exists}%name%#{br}#{"</a>".if_exists('aref')}</span>".if_exists('name').loop(item)
                    end.if_exists(item)
                  end

                  div.spacer! ''

                  # for the javascript ajaxy includes
                  ['class', 'file', 'method'].each do |item|
                    div.navigation.dark.index :id => "#{item}_wrapper" do
                     div.list_header do
                       h3 'All ' + (item == 'class' ? 'classes' : item + 's')
                     end
                     div.list_header_link do
                       a((item == 'method' ? 'Show...' : 'Hide...'),
                          :id => "#{item}_link", :href => "#",
                          :onclick=> "toggle('#{item}'); toggleText('#{item}_link'); return false;")
                     end
                     div.clear {}
                     div(:id => item) do
                       form do
                         label(:for => "filter_#{item}") { 'Filter:' + '&nbsp;' * 2 }
                         input '', :type => 'text', :id => "filter_#{item}",
                                     :onKeyUp => "return filterList('#{item}', this.value, event);",
                                     :onKeyPress => "return disableSubmit(event);"
                       end
                     end
                     # insert classes here...
                    end
                  end
                end

                td.content! do
                  self << capture do
                    h1.item_name! '%title%'
                  end.if_exists('title')

                  self << capture do
                    self << '%description%'
                  end.if_exists('description')

                  self << capture do
                    self << h1 {a '%sectitle%', :name => '%secsequence%'}.if_exists('sectitle')
                    self << p {'%seccomment%'}.if_exists

                    self << capture do
                      h1 "Child modules and classes"
                      p '%classlist%'
                    end.if_exists('classlist')

                    ['constants', 'aliases', 'attributes'].each do |item|
                      self << capture do
                        h1(item.capitalize)
                        p do
                          table do
                            fields = %w[name value old_name new_name rw desc a_desc]
                            self << tr do
                              # header row
                              if item == 'constants'
                                th 'Name'
                                th 'Value'
                              elsif item == 'aliases'
                                th 'Old name'
                                th 'New name'
                              elsif item == 'attributes'
                                th 'Name'
                                th 'Read/write?'
                              end
                              th.description(:colspan => 2){"Description"}
                            end
                            self << tr do
                              # looped item rows
                              fields.each do |field|
                                if field !~ /desc/
                                  self << td('%' + field + '%', :class => field =~ /^old|^name/ ? "highlight" : "normal").if_exists
                                else
                                  self << td(('%' + field+ '%').if_exists)
                                end
                              end
                            end.loop(item)
                          end
                        end
                      end.if_exists(item)
                    end

                    self << capture do
                      div.section_spacer ''
                      h1('%type% %category% methods')
                      self << capture do
                        self << a.small(:name => '%aref%') {br}.if_exists
                        div.a_method do
                          div do
                            h3 do
                              self << "<a href='#%aref%'>".if_exists + '%callseq%'.if_exists + '%name%'.if_exists + "</a>".if_exists('aref')+'<span class="params">%params%</span>'.if_exists('params')
                            end
                            self << '%m_desc%'.if_exists

                            self << capture do
                             p.source_link :id => '%aref%-show-link' do
                               self << "[ "
                               a "show source", :id => '%aref%-link', :href => "#",
                                             :onclick=> "toggle('%aref%-source'); toggleText('%aref%-link'); return false;"
                               self << " ]"
                             end
                             div.source :id => '%aref%-source' do
                                  pre { '%sourcecode%' }
                               end
                             end.if_exists('sourcecode')
                            end
                          end

                      end.loop('methods').if_exists('methods')
                    end.loop('method_list').if_exists('method_list')

                  end.loop('sections').if_exists('sections')

                end
              end
            end
            p.allison! do
               self << 'template adapted from '
               a 'Allison', :href => URL
            end
          end
        end.to_s
      end

    Allison.constants.each do |c|
      eval "#{c} = Allison::#{c}" # jump out of the namespace
      File.open("#{CACHE_DIR}/#{c}", 'w') do |f|
        f.puts eval(c) # write cache
      end
    end

    rescue LoadError => e
      # guess we don't have some dependency. hope the cache is fresh!
      lib = (e.to_s[/(.*)\(/, 1] or e.to_s).split(" ").last.capitalize
      puts "Loading from cache (#{lib} was missing)..."
      Dir[CACHE_DIR + '/*'].each do |filename|
        eval("#{filename.split("/").last} = File.open(filename) {|s| s.read}")
      end
    end

  end

end
