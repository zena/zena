require 'digest/sha1'
module Bricks
  module Math
    module ViewMethods
      def math_asset(opts)
        content    = opts[:content]
        node       = opts[:node]
        if !(content =~ /^\s*\\begin\{(align|equation|itemize|equation)/)
          pre = '\['
          post = '\]'
        else
          pre = post = ''
        end

        # FIXME: SECURITY LateX filtering: is this enough ?
        if content =~ /\\input/
          return "<span class='math_preview'>#{content.gsub(/(\\input\w*)/, "<span style=\'color:red;\'>#{$1}</span> (not supported)")}</span>"
        end

        if opts[:output] == 'latex'
          "#{pre}#{content}#{post}"
        elsif Zena::ENABLE_MATH
          # Create PNG image
          # 1. get image path
          math_id  = Digest::SHA1.hexdigest(content)[0..4]
          filename = math_id + '.png'
          filepath = node.asset_path(filename)
          unless File.exist?(filepath)
            if opts[:preview]
              # do not render image during preview
              tag = content =~ /\n/ ? 'pre' : 'span'
              return "<#{tag} class='math_preview'>#{content}</#{tag}>"
            else
              # create image
              FileUtils::mkpath(File.dirname(filepath)) unless File.exist?(File.dirname(filepath))
              begin
                tempf = Tempfile.new(filename) # TODO: do we need to close this file ?
                base = tempf.path
                latex_template = %q{
\documentclass[10pt]{article}
\usepackage[utf8]{inputenc}
\usepackage{amssymb}

\usepackage{amsmath}
\usepackage{amsfonts}
\usepackage{ulem}     % strikethrough (\sout{...})
\usepackage{hyperref} % links


% shortcuts
\DeclareMathOperator*{\argmin}{arg\,min}
\newcommand{\ve}[1]{\boldsymbol{#1}}
\newcommand{\ma}[1]{\boldsymbol{#1}}
\newenvironment{m}{\begin{bmatrix}}{\end{bmatrix}}

\pagestyle{empty}
\begin{document}

}

                File.open("#{base}.tex", 'wb') do |f|
                  f.syswrite(latex_template)
                  f.syswrite(pre)
                  f.syswrite(content)
                  f.syswrite(post)
                  f.syswrite("\n\\end{document}\n")
                end

                system("cd #{File.dirname(tempf.path)}; latex -interaction=batchmode #{"#{base}.tex".inspect} &> '#{base}.err'")
                if !File.exists?("#{base}.dvi")
                  Node.logger.error(File.read("#{base}.err"))
                  system("cp '#{Zena::ROOT}/public/world.png' #{filepath.inspect}")
                else
                  system("dvips #{tempf.path}.dvi -E -o #{base}.ps &> '#{base}.err'") #||  Node.logger.error(File.read("#{base}.err"))
                  system("convert -units PixelsPerInch -density 150 -matte -fuzz '10%' -transparent '#ffffff' #{base}.ps #{filepath.inspect} &> '#{base}.err'") #|| Node.logger.error(File.read("#{base}.err"))
                end

              ensure
                system("rm -rf #{tempf.path.inspect} #{(tempf.path + '.*').inspect}")
              end
            end
          end
          "<span class='math'><img src='#{zen_path(node, :asset => math_id, :format => 'png')}'/></span>"
        else
          # Math not supported
          "[math]#{content}[/math]"
        end
      end
    end # ViewMethods
  end # Math
end # Bricks
