require 'safe_yaml'
SafeYAML::OPTIONS[:default_mode] = :safe
require 'date'
require 'fileutils'
require 'zena/info'
require 'bricks'

# FIXME: ========== cleanup
SITES_ROOT = "#{RAILS_ROOT}/sites"
AUTHENTICATED_PREFIX = "oo"
PASSWORD_SALT = "jf93jfnvnas09093nas0923" # type anything here (but change this line !)
ZENA_CALENDAR_LANGS = ["en", "fr", "de"] # FIXME: build this dynamically from existing files
ENABLE_XSENDFILE = false

module Zena
  def self.has_executable(*list)
    return false if RUBY_PLATFORM =~ /mswin32/
    list.inject(true) do |s,e|
      s && !(`which #{e} || echo 'no #{e}'` =~ /^no #{e}/)
    end
  end

  ASSET_PORT     = Bricks.raw_config['asset_port'].to_i
  LOCAL_IPS      = ((Bricks.raw_config['local_ips'] || '').split(',').map(&:strip) + %w{127.0.0.1 ::1}).uniq
  

  ENABLE_LATEX   = true  && has_executable('pdflatex') # enable LateX post-rendering
  ENABLE_FOP     = true  && has_executable('fop', 'xsltproc') # enable xsl-fo post-rendering
  ENABLE_MATH    = true  && has_executable('latex', 'dvips', 'convert', 'gs')

  module DbHelper
  end

  # VERSION is defined in root.rb
  class << self
    attr_accessor :tools_enabled

    # Resolve a fully defined constant like 'Bricks::Pdf::Engine::Prince'
    def resolve_const(klass)
      if klass.kind_of?(String)
        constant = nil
        # Foo.const_get('Bar') is not guaranteed to find/load Foo::Bar, it can return just Bar.
        if klass =~ /\A[^A-Z\:]|[^0-9a-zA-Z\:]/
          raise NameError.new("Invalid constant name: #{klass.inspect}.")
        end
        eval "::#{klass}"
      else
        klass
      end
    end

    def add_load_paths(config = nil)
      paths_to_add = (
        Dir["#{Zena::ROOT}/vendor/gems/*/lib"] +
        Dir["#{Zena::ROOT}/vendor/plugins/*/lib"] +
        Bricks.models_paths
      )
      if config
        ["#{Zena::ROOT}/vendor", "#{Zena::ROOT}/lib"].each do |path|
          ActiveSupport::Dependencies.autoload_paths      << path
          ActiveSupport::Dependencies.autoload_once_paths << path
          $LOAD_PATH                                      << path
        end
      else
        paths_to_add.each do |path|
          $LOAD_PATH.push path
        end
      end
    end

    def log_path
      "#{RAILS_ROOT}/log/#{RAILS_ENV}.log"
    end

    def enable_tools
      # TODO: move all code from environment.rb here...
      @tools_enabled ||= {:Latex => Zena::ENABLE_LATEX, :fop => Zena::ENABLE_FOP, :math => Zena::ENABLE_MATH}.map{|k,v| v ? k : nil}.compact
    end

    def include_modules
      ActionController::Routing::RouteSet::Mapper.send :include, Zena::Routes


      # FIXME: make this explicit in models
      ActiveRecord::Base.send :include, Zena::Acts::Secure
      ActionController::Base.send :include, Zena::Acts::Secure

    end

    def require_in_lib(name, dir, lib_name = nil)
      if defined?(ActiveRecord)
        # late loading, require
        base = Dir["#{dir}/*#{name}*"].first
        lib_path = "#{base}/lib/#{lib_name || name}"
        lib_path += '.rb' unless lib_path =~ /\.rb$/
        if File.exist?(lib_path)
          require lib_path
        else
          puts "Could not require #{lib_path.inspect}"
        end
      end
    end

    def gem_configuration
      conf = open("#{Zena::ROOT}/config/gems.yml") {|f| YAML.load(f.read)}
      res = {}
      conf.each do |k, v|
        if v.kind_of?(String)
          res[k] = {'version' => v}
        else
          res[k] = v
        end
      end
      res
    end

    def gems_setup
      gem_configuration.each do |gem_name, gem_config|
        if gem_config
          if gem_config['optional']
            if brick_name = gem_config['brick']
              unless Bricks::CONFIG[brick_name]
                next
              end
            end
            begin
              gem gem_name, gem_config['version']
            rescue LoadError
              # ignore
            end
          else
            gem gem_name, gem_config['version']
          end
        else
          gem gem_name
        end
      end
    end

    def config_gems(config)
      gem_configuration.each do |gem_name, gem_config|
        if gem_config
          conf = gem_config.symbolize_keys
          if conf[:version]
            conf[:version].gsub!(/\A=\s*/,'')
          end
          if conf[:optional]
            if brick = conf[:brick]
              if Bricks::CONFIG[brick]
                config.gem gem_name, conf
              end
            else
              begin
                config.gem gem_name, conf
              rescue LoadError
                # ignore
              end
            end
          else
            config.gem gem_name, conf
          end
        else
          config.gem gem_name
        end
      end
    end

    def load_plugins
      Dir.foreach("#{Zena::ROOT}/vendor/plugins") do |plugin_name|
        next if plugin_name =~ /\A\./
        require_in_lib plugin_name, "#{Zena::ROOT}/vendor/plugins"
      end
      # init.rb not evaluated in responds-to-parent
      ActionController::Base.send :include, RespondsToParent
    end

    def load_custom_extensions
      #FIXME: cleanup all these hacks !
      lib_path = File.join(Zena::ROOT, 'lib/zena')
      Dir.foreach(File.join(lib_path, 'core_ext')) do |f|
        next unless f =~ /\.rb\Z/
        require File.join(lib_path, 'core_ext', f)
      end
      require File.join(lib_path, 'base_additions')
      require File.join(lib_path, 'fix_rails_layouts.rb') # FIXME: remove when https://rails.lighthouseapp.com/projects/8994/tickets/3207 approved
    end

    # The dependencies listed here need to be loaded in this order to make sure
    # AfterCommit is included before the first connection to the database.
    def require_ordered_dependencies
      require 'versions'
      require 'property'
    end

    def set_default_timezone(config)
      # Make Active Record use UTC-base instead of local time
      # do not change this !
      ActiveRecord::Base.default_timezone = :utc
      ENV['TZ'] = 'UTC'
    end

    def add_inflections
      ActiveSupport::Inflector.inflections do |inflect|
        inflect.uncountable %w( children )
      end
    end

    def initialize_gettext
      require 'fast_gettext'

      FastGettext.add_text_domain 'zena', :path => "#{Zena::ROOT}/locale" #File.dirname(__FILE__) + '/../../locale'
      FastGettext.default_text_domain = 'zena'
      FastGettext.text_domain = 'zena'
    end

    def initialize_authlogic
      require "authlogic"
    end

    # Nicer syntax: Zena.use Bricks:Foobar instead of Zena::Use.module Bricks::Foobar
    def use(*args)
      Zena::Use.module(*args)
    end

    def init
      config = Rails.configuration
      enable_tools
      puts "** zena #{Zena::VERSION} starting (c) Gaspard Bucher 2012"
      puts "** Bricks: #{Bricks::CONFIG.map{|k,v| k}.sort.join(', ')}"

      add_load_paths(config)
      config_gems(config)
      set_default_timezone(config)
      Zena::Db.prepare_connection

      require_ordered_dependencies

      # This is needed for idx fields taming (lock table content in OR clause).
      # Must come after 'require_ordered_dependencies' so that AfterCommit is loaded
      # before first DB usage.
      Zena::Db.insert_dummy_ids

      load_plugins if RAILS_ROOT != Zena::ROOT
      include_modules
      Bricks.load_bricks
      add_inflections
      initialize_authlogic
      initialize_gettext
    end
  end
end


# test if DRB started
if RAILS_ENV == 'production' && defined?(Mongrel) && !File.exist?(File.join(File.dirname(__FILE__), '..', 'log', 'upload_progress_drb.pid'))
  puts "\n** WARNING: drb server not running. Upload progress will not work using Mongrel."
  puts " * WARNING: you should start the drb server with 'lib/upload_progress_server.rb start'\n\n"
end

unless File.exist?(File.join(RAILS_ROOT, 'config', 'database.yml'))
  FileUtils.cp(File.join(Zena::ROOT, 'config', 'database_example.yml'), File.join(RAILS_ROOT, 'config', 'database.yml'))
end

%w{log sites}.each do |dir|
  path = File.join(RAILS_ROOT, dir)
  if !File.exist?(path) && !File.symlink?(path)
    FileUtils.mkpath(path)
  end
end

# FIXME: use another mime types library...
# this list is taken from http://www.duke.edu/websrv/file-extensions.html
EXT_TYPE = [
  [ "ai"        , "application/postscript"         ],
  [ "aif"       , "audio/x-aiff"                   ],
  [ "aifc"      , "audio/x-aiff"                   ],
  [ "aiff"      , "audio/x-aiff"                   ],
  [ "au"        , "audio/basic"                    ],
  [ "avi"       , "video/x-msvideo"                ],
  [ "bcpio"     , "application/x-bcpio"            ],
  [ "bin"       , "application/octet-stream"       ],
  [ "ccad"      , "application/clariscad"          ],
  [ "cdf"       , "application/x-netcdf"           ],
  [ "class"     , "application/octet-stream"       ],
  [ "cpio"      , "application/x-cpio"             ],
  [ "cpt"       , "application/mac-compactpro"     ],
  [ "csh"       , "application/x-csh"              ],
  [ "css"       , "text/css"                       ],
  [ "dcr"       , "application/x-director"         ],
  [ "dir"       , "application/x-director"         ],
  [ "dms"       , "application/octet-stream"       ],
  [ "doc"       , "application/msword"             ],
  [ "docx"      , "application/vnd.openxmlformats-officedocument.wordprocessingml.document"             ],
  [ "drw"       , "application/drafting"           ],
  [ "dvi"       , "application/x-dvi"              ],
  [ "dwg"       , "application/acad"               ],
  [ "dxf"       , "application/dxf"                ],
  [ "dxr"       , "application/x-director"         ],
  [ "eps"       , "application/postscript"         ],
  [ "etx"       , "text/x-setext"                  ],
  [ "exe"       , "application/octet-stream"       ],
  [ "ez"        , "application/andrew-inset"       ],
  [ "fli"       , "video/x-fli"                    ],
  [ "gif"       , "image/gif"                      ],
  [ "gtar"      , "application/x-gtar"             ],
  [ "gz"        , "application/x-gzip"             ],
  [ "hdf"       , "application/x-hdf"              ],
  [ "hqx"       , "application/mac-binhex40"       ],
  [ "html"      , "text/html"                      ],
  [ "htm"       , "text/html"                      ],
  [ "ice"       , "x-conference/x-cooltalk"        ],
  [ "ief"       , "image/ief"                      ],
  [ "iges"      , "model/iges"                     ],
  [ "igs"       , "model/iges"                     ],
  [ "ips"       , "application/x-ipscript"         ],
  [ "ipx"       , "application/x-ipix"             ],
  [ "jpg"       , "image/jpeg"                     ],
  [ "jpe"       , "image/jpeg"                     ],
  [ "jpeg"      , "image/jpeg"                     ],
  [ "js"        , "application/x-javascript"       ],
  [ "js"        , "text/javascript"                ],
  [ "kar"       , "audio/midi"                     ],
  [ "latex"     , "application/x-latex"            ],
  [ "lha"       , "application/octet-stream"       ],
  [ "lsp"       , "application/x-lisp"             ],
  [ "lzh"       , "application/octet-stream"       ],
  [ "man"       , "application/x-troff-man"        ],
  [ "me"        , "application/x-troff-me"         ],
  [ "mesh"      , "model/mesh"                     ],
  [ "mid"       , "audio/midi"                     ],
  [ "midi"      , "audio/midi"                     ],
  [ "mif"       , "application/vnd.mif"            ],
  [ "mime"      , "www/mime"                       ],
  [ "mov"       , "video/quicktime"                ],
  [ "movie"     , "video/x-sgi-movie"              ],
  [ "mp2"       , "audio/mpeg"                     ],
  [ "mp3"       , "audio/mpeg"                     ],
  [ "mp4"       , "video/mp4"                      ],
  [ "m4v"       , "video/mp4"                      ],
  [ "mpe"       , "video/mpeg"                     ],
  [ "mpeg"      , "video/mpeg"                     ],
  [ "mpg"       , "video/mpeg"                     ],
  [ "mpga"      , "audio/mpeg"                     ],
  [ "ms"        , "application/x-troff-ms"         ],
  [ "msh"       , "model/mesh"                     ],
  [ "nc"        , "application/x-netcdf"           ],
  [ "oda"       , "application/oda"                ],
  [ "pbm"       , "image/x-portable-bitmap"        ],
  [ "pdb"       , "chemical/x-pdb"                 ],
  [ "pdf"       , "application/pdf"                ],
  [ "pgm"       , "image/x-portable-graymap"       ],
  [ "pgn"       , "application/x-chess-pgn"        ],
  [ "png"       , "image/png"                      ],
  [ "pnm"       , "image/x-portable-anymap"        ],
  [ "pot"       , "application/mspowerpoint"       ],
  [ "ppm"       , "image/x-portable-pixmap"        ],
  [ "pps"       , "application/mspowerpoint"       ],
  [ "ppt"       , "application/mspowerpoint"       ],
  [ "pptx"      , "application/vnd.openxmlformats-officedocument.presentationml.presentation"       ],
  [ "ppz"       , "application/mspowerpoint"       ],
  [ "pre"       , "application/x-freelance"        ],
  [ "prt"       , "application/pro_eng"            ],
  [ "ps"        , "application/postscript"         ],
  [ "qt"        , "video/quicktime"                ],
  [ "ra"        , "audio/x-realaudio"              ],
  [ "ram"       , "audio/x-pn-realaudio"           ],
  [ "ras"       , "image/cmu-raster"               ],
  [ "rb"        , "text/x-ruby-script"             ],
  [ "rgb"       , "image/x-rgb"                    ],
  [ "rm"        , "audio/x-pn-realaudio"           ],
  [ "roff"      , "application/x-troff"            ],
  [ "rpm"       , "audio/x-pn-realaudio-plugin"    ],
  [ "rss"       , "application/rss+xml"            ],
  [ "rtf"       , "text/rtf"                       ],
  [ "rtx"       , "text/richtext"                  ],
  [ "scm"       , "application/x-lotusscreencam"   ],
  [ "set"       , "application/set"                ],
  [ "sgm"       , "text/sgml"                      ],
  [ "sgml"      , "text/sgml"                      ],
  [ "sh"        , "application/x-sh"               ],
  [ "shar"      , "application/x-shar"             ],
  [ "silo"      , "model/mesh"                     ],
  [ "sit"       , "application/x-stuffit"          ],
  [ "skd"       , "application/x-koan"             ],
  [ "skm"       , "application/x-koan"             ],
  [ "skp"       , "application/x-koan"             ],
  [ "skt"       , "application/x-koan"             ],
  [ "smi"       , "application/smil"               ],
  [ "smil"      , "application/smil"               ],
  [ "snd"       , "audio/basic"                    ],
  [ "sol"       , "application/solids"             ],
  [ "spl"       , "application/x-futuresplash"     ],
  [ "src"       , "application/x-wais-source"      ],
  [ "step"      , "application/STEP"               ],
  [ "stl"       , "application/SLA"                ],
  [ "stp"       , "application/STEP"               ],
  [ "sv4cpio"   , "application/x-sv4cpio"          ],
  [ "sv4crc"    , "application/x-sv4crc"           ],
  [ "swf"       , "application/x-shockwave-flash"  ],
  [ "t"         , "application/x-troff"            ],
  [ "tgz"       , "application/x-gzip"             ],
  [ "tar"       , "application/x-tar"              ],
  [ "tcl"       , "application/x-tcl"              ],
  [ "tex"       , "application/x-tex"              ],
  [ "texi"      , "application/x-texinfo"          ],
  [ "texinf"    , "application/x-texinfo"          ],
  [ "txt"       , "text/plain"                     ],
  [ "hh"        , "text/plain"                     ],
  [ "h"         , "text/plain"                     ],
  [ "hpp"       , "text/plain"                     ],
  [ "asc"       , "text/plain"                     ],
  [ "c"         , "text/plain"                     ],
  [ "m"         , "text/plain"                     ],
  [ "cc"        , "text/plain"                     ],
  [ "cpp"       , "text/plain"                     ],
  [ "f"         , "text/plain"                     ],
  [ "f90"       , "text/plain"                     ],
  [ "tiff"      , "image/tiff"                     ],
  [ "tr"        , "application/x-troff"            ],
  [ "tsi"       , "audio/TSP-audio"                ],
  [ "tsp"       , "application/dsptype"            ],
  [ "tsv"       , "text/tab-separated-values"      ],
  [ "unv"       , "application/i-deas"             ],
  [ "ustar"     , "application/x-ustar"            ],
  [ "vcd"       , "application/x-cdlink"           ],
  [ "vcf"       , "text/x-vCard"                   ],
  [ "vcard"     , "text/x-vCard"                   ],
  [ "vda"       , "application/vda"                ],
  [ "viv"       , "video/vnd.vivo"                 ],
  [ "vivo"      , "video/vnd.vivo"                 ],
  [ "vrml"      , "model/vrml"                     ],
  [ "wav"       , "audio/x-wav"                    ],
  [ "wrl"       , "model/vrml"                     ],
  [ "xbm"       , "image/x-xbitmap"                ],
  [ "xlc"       , "application/vnd.ms-excel"       ],
  [ "xll"       , "application/vnd.ms-excel"       ],
  [ "xlm"       , "application/vnd.ms-excel"       ],
  [ "xls"       , "application/vnd.ms-excel"       ],
  [ "xlsx"      , "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"       ],
  [ "xlw"       , "application/vnd.ms-excel"       ],
  [ "xml"       , "text/xml"                       ],
  [ "xsl"       , "text/xml"                       ],
  [ "xslt"      , "text/xml"                       ],
  [ "xpm"       , "image/x-xpixmap"                ],
  [ "xwd"       , "image/x-xwindowdump"            ],
  [ "xyz"       , "chemical/x-pdb"                 ],
  [ "yml"       , "text/yaml"                      ],
  [ "zafu"      , "text/zafu"                      ],
  [ "zip"       , "application/zip"                ],
  [ "zml"       , "text/znode"                     ],
]

def make_hashes(h)
  val_to_keys = {}
  keys_to_val = {}
  h.each do |e|
    k,v = e
    if keys_to_val[k]
      keys_to_val[k] << v
    else
      keys_to_val[k] = [v]
    end

    if val_to_keys[v]
      val_to_keys[v] << k
    else
      val_to_keys[v] = [k]
    end
  end
  [keys_to_val, val_to_keys]
end

Zena::EXT_TO_TYPE, Zena::TYPE_TO_EXT = make_hashes(EXT_TYPE)
Zena.add_load_paths
Zena.gems_setup
Zena.load_custom_extensions
require 'rubyless'
