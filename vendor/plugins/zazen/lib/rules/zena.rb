module Zazen
  module Rules
    # create a gallery ![...]!
    add_rule( /\!\[([^\]]*)\]\!/ ) do |parse|
      if parse[:images]
        parse.helper.make_gallery(parse[1])
      else
        parse.helper.trans('[gallery]')
      end
    end

    # list of documents !<.{...}!
    add_rule( /\!([^0-9]{0,2})\{([^\}]*)\}\!/ ) do |parse|
      if parse[:images]
        parse.helper.list_nodes(:style=>parse[1], :ids=>parse[2])
      else
        parse.helper.trans('[documents]')
      end
    end

    # image !<.12.pv/blah blah!:12
    add_rule( /\!([^0-9]{0,2})([0-9]+)(\.([^\/\!]+)|)(\/([^\!]*)|)\!(:([^\s]+)|)/ ) do |parse|
      parse.helper.make_image(:style=>parse[1], :id=>parse[2], :size=>parse[4], :title=>parse[6], :link=>parse[8], :images=>parse[:images])
    end

    # link inside the cms "":34
    add_rule( /"([^"]*)":([0-9]+)/ ) do |parse|
      parse.helper.make_link(:title=>parse[1],:id=>parse[2])
    end

    # wiki reference ?zafu? or ?zafu?:http://...
    add_after_rule( /\?(\w[^\?]+?\w)\?([^\w:]|:([^\s]+))/ ) do |parse|
      if parse[3]
        if parse[3] =~ /([^\w0-9])$/
          parse.helper.make_wiki_link(:title=>parse[1], :url=>parse[3][0..-2]) + $1
        else
          parse.helper.make_wiki_link(:title=>parse[1], :url=>parse[3])
        end
      else
        parse.helper.make_wiki_link(:title=>parse[1]) + parse[2]
      end
    end
  end
end