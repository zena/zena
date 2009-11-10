require "#{ENV['TM_SUPPORT_PATH']}/lib/scriptmate"
require 'cgi'

$SCRIPTMATE_VERSION = "$Revision: 6354 $"

class RubyScript < UserScript
  attr_reader :test_name, :base_path, :path, :content
  def lang; 'Ruby' end
  def executable; @hashbang || ENV['TM_RUBY'] || 'ruby' end
  def args; ['-rcatch_exception', '-rstdin_dialog'] end
  def version_string
    ruby_path = %x{ #{executable} -e 'require "rbconfig"; print Config::CONFIG["bindir"] + "/" + Config::CONFIG["ruby_install_name"]'}
    res = "Ruby r" + %x{ #{executable} -e 'print RUBY_VERSION' }
    res + " (#{ruby_path})"
  end
  def test_script?
    @path    =~ /(?:\b|_)(?:tc|ts|test)(?:\b|_)/ or
    @content =~ /\brequire\b.+(?:test\/unit|test_helper)/
  end
  def filter_cmd(cmd)
    cmd -= [ENV['TM_FILEPATH']]
    if test_script?
      path_ary = @path.split('/')
      if index = path_ary.rindex('test')
        test_path = File.join(*path_ary[0..index])
        lib_path  = File.join( *( path_ary[0..-2] +
                                  ['..'] * (path_ary.length - index - 1) ) +
                                  ['lib'] )
        if File.exist? lib_path
          cmd.insert(1, "-I#{e_sh lib_path}:#{e_sh test_path}")
        end
      end
    end
    if index = cmd.rindex('--name')
      @test_name = cmd[index+1]
      @base_path = cmd[index-1].gsub(/\_test.rb$/,'')
    else
      @base_path = cmd.last.gsub(/\_test.rb$/,'')
    end
    @cmd = cmd
  end
end

class RubyMate < ScriptMate
  def base_path
    @base_path ||= begin
      path_ary = @command.path.split('/')
      if index = path_ary.rindex('test')
        File.join(*path_ary[0..(index -1)])
      else
        @command.path
      end
    end
  end

  def run
    super
  rescue => err
    File.open('/Users/gaspard/yaml.log', 'ab') do |f|
      f.puts err.message
      f.puts err.backtrace.join("\n")
    end
    raise err
  end

  def absolute_path(path)
    if path =~ %r{\A/}
      path
    else
      "#{base_path}/#{path}"
    end
  end

  def full_method_name(file, method)
    if absolute_path(file) == @command.path
      method
    else
      "#{File.basename(file)} #{method}"
    end
  end

  def filter_stdout(str)
    if @command.test_script? and str =~ /\A[.EF]+\Z/
      # ...F....E....
      htmlize(str).gsub(/[EF]+/, "<span style=\"color: red\">\\&</span>") + "<br style=\"display: none\"/>"
    else
      if @command.test_script?
        str.map do |line|
          if line =~ %r{\(eval\).*in `(test_(\w+?)_(.*))'}
            test_name = $1
            group, method = $2, $3
            begin
              file  = File.join(@command.base_path, "#{group}.yml")
              lines = File.read(file).split("\n")
              position  = lines.rindex { |l| l =~ %r{^#{method}:} } + 1
              "<span><a class='near' href=\"txmt://open?url=file://#{e_url(file)}&amp;line=#{position}\">#{test_name}</a></span>:#{position}<br/>"
            rescue => err
              line
            end
          elsif line =~ /^\d+ tests, \d+ assertions, (\d+) failures, (\d+) errors/
            "<span style=\"color: #{$1 + $2 == "00" ? "green" : "red"}\">#{$&}</span><br/>"
          elsif line =~ /Loaded suite/ && @command.test_name
            htmlize(line.chomp + " --name #{@command.test_name}\n")
          elsif line =~ /`yt_|\(eval\)/
            nil
          else
            htmlize(line)
          end
        end.compact.join
      else
        htmlize(str)
      end
    end
  end
end

script = RubyScript.new(STDIN.read)
RubyMate.new(script).emit_html
