require "#{ENV["TM_SUPPORT_PATH"]}/lib/scriptmate"
require "cgi"

$SCRIPTMATE_VERSION = "$Revision: 8136 $"

class TrivialScript < UserCommand
  attr_reader :lang
  def initialize(*args)
    super
    @cmd = "ruby #{ARGV.join(' ')}"
    @display_name = ARGV.last
    @lang         = "Ruby"
  end
  def version_string
    ruby_path = %x{ ruby -e 'require "rbconfig"; print Config::CONFIG["bindir"] + "/" + Config::CONFIG["ruby_install_name"]'}
    res = "Ruby r" + %x{ ruby -e 'print RUBY_VERSION' }
    res + " (#{ruby_path})"
  end
  def args; ['-rcatch_exception', '-rstdin_dialog'] end
  def run
    stdin, stdout, stderr, pid = my_popen3(@cmd)
    return stdout, stderr, nil, pid
  end
end

class RubyMate < ScriptMate
  def filter_stdout(str)
    if str =~ /\A[.EF]+\Z/
      return htmlize(str).gsub(/[EF]+/, "<span style=\"color: red\">\\&</span>") +
            "<br style=\"display: none\"/>"
    else
      str.map do |line|
        if line =~ /^(\s+)(\S.*?):(\d+)(?::in\s*`(.*?)')?/
          indent, file, line, method = $1, $2, $3, $4
          url, display_name = '', 'untitled document';
          unless file == "-"
            indent += " " if file.sub!(/^\[/, "")
            url = '&amp;url=file://' + e_url(file)
            display_name = File.basename(file)
          end
          if method =~ /^test_([a-zA-Z]+)_(.*)/
            line = 0
            yaml_file, test_name = $1, $2
            file_path = File.join(File.dirname(ENV['TM_FILEPATH']), "#{yaml_file}.yml")
            $file_contents[file_path] ||= File.read(file_path)
            $file_contents[file_path].split("\n").each do |l|
              line += 1
              break if l =~ /^#{test_name}:/
            end
            line = line.to_s
            url = '&amp;url=file://' + e_url(file_path)
          end
          "#{indent}<a class='near' href='txmt://open?line=#{line + url}'>" +
          (method ? "method #{CGI::escapeHTML method}" : '<em>at top level</em>') +
          "</a> in <strong>#{CGI::escapeHTML display_name}</strong> at line #{line}<br/>"
        elsif line =~ /(\[[^\]]+\]\([^)]+\))\s+\[([\w\_\/\.]+)\:(\d+)\]/
          spec, file, line = $1, $2, $3, $4
          "<span><a style=\"color: blue;\" href=\"txmt://open?url=file://#{e_url(file)}&amp;line=#{line}\">#{spec}</span>:#{line}<br/>"
        elsif line =~ /([\w\_]+).*\[([\w\_\/\.]+)\:(\d+)\]/
          method, file, line = $1, $2, $3
          "<span><a style=\"color: blue;\" href=\"txmt://open?url=file://#{e_url(file)}&amp;line=#{line}\">#{method}</span>:#{line}<br/>"
        elsif line =~ /^\d+ tests, \d+ assertions, (\d+) failures, (\d+) errors\b.*/
          "<span style=\"color: #{$1 + $2 == "00" ? "green" : "red"}\">#{$&}</span><br/>"
        else
          htmlize(line)
        end
      end.join
    end
  end
end
$file_contents = {}
$file_contents[ENV['TM_FILEPATH']] = STDIN.read
script = TrivialScript.new($file_content)
RubyMate.new(script).emit_html