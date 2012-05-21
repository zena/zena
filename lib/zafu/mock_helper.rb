module Zafu
  # This is the 'src_helper' used when none is provided. Its main purpose is to provide some information
  # during testing.
  class MockHelper
    def initialize(strings = {})
      @strings = strings
    end

    def get_template_text(opts)
      src    = opts[:src]
      folder = (opts[:base_path] && opts[:base_path] != '') ? opts[:base_path][1..-1].split('/') : []
      src = src[1..-1] if src[0..0] == '/' # just ignore the 'relative' or 'absolute' tricks.
      url = (folder + src.split('/')).join('_')
      if test = @strings[url]
        return [test['src'], url.split('_').join('/')]
      else
        nil
      end
    end

    def template_url_for_asset(opts)
      "/test_#{opts[:type]}/#{opts[:src]}"
    end

    def method_missing(sym, *args)
      arguments = args.map do |arg|
        if arg.kind_of?(Hash)
          res = []
          arg.each do |k,v|
            unless v.nil?
              res << "#{k}:#{v.inspect.gsub(/'|"/, "|")}"
            end
          end
          res.sort.join(' ')
        else
          arg.inspect.gsub(/'|"/, "|")
        end
      end
      res = "[#{sym} #{arguments.join(' ')}]"
    end
  end # DummyHelper
end