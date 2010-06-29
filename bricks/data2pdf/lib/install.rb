require 'open-uri'
require 'digest/md5'
require 'digest/sha1'
require 'fileutils'

# begin
#   cmd = 'which python'
#   unless system cmd
#     puts 'FATAL: python 2.6.1+ must be installed'
#     exit
#   end
# end

module Data2pdf
  class Install

    # Utility to install library necessary to Data2pdf on unix like machine.
    #
    # To install xhtml2pdf and his dependencies, run these commands :
    #
    # Data2pdf::Install.from_url "http://pypi.python.org/packages/source/p/pisa/pisa-3.0.32.tar.gz", :md5=>'d68f2f76e04b10f73c07ef4df937b243'
    #
    # Data2pdf::Install.from_url "http://www.reportlab.com/ftp/ReportLab_2_4.tar.gz", :md5=>'e6dc4b0fbfb6814f7777e5960774cb5d'
    #
    # Data2pdf::Install.from_url 'http://html5lib.googlecode.com/files/html5lib-0.11.1.zip', :sha1=>'157506319e40f5d973c128e5e2b826cd1bee471e'
    #
    # Data2pdf::Install.from_url 'http://effbot.org/downloads/Imaging-1.1.7.tar.gz'
    #
    # Data2pdf::Install.from_url 'http://pybrary.net/pyPdf/pyPdf-1.12.tar.gz'

    include FileUtils::Verbose

    attr_reader :url, :file, :md5, :sha1, :force

    def self.from_url url, opts={}
      puts "INFO: start installation of #{url}"
      self.new url, opts do |install|
        install.download
        install.checksum if install.do_checksum?
        install.deflate
        install.setup
      end
      puts "INFO: end installation of #{url}"
    end

    def initialize url, opts={}
      @url    = url
      @file   = url.split('/').last
      @md5    = opts.delete :md5
      @sha1   = opts.delete :sha1
      @force  = opts.delete :forc
      yield self if block_given?
    end

    def download
      open file, 'w' do |io|
        io.write open(url).read
      end
      puts "INFO: #{file} downloaded" if downloaded?
    end

    def checksum
      integrity = if md5
        @digest = Digest::MD5.hexdigest(File.read file)
        @digest == md5
      elsif sha1
        @digest = Digest::SHA1.hexdigest(File.read file)
        @digest == sha1
      end

      unless integrity || force
        puts "WARN: Invalid checksum #{@digest} for #{file}"
        exit
      else
        true
      end
    end

    def deflate
      cmd = "nice -n 15 tar xvfz #{file}"
      success = system cmd
      puts "INFO: #{file} deflated" if success && $?.exited?
    end

    def setup
      cd "./#{folder}" do
        cmd = "sudo nice -n 15 python setup.py install"
        success = system cmd
      end
    end

    def folder
       @file.gsub('.tar','').gsub('.gz','').gsub('.zip','')
    end

    def downloaded?
      true if File.stat(file).size?
    end

    def do_checksum?
      md5 || sha1
    end

  end
end






