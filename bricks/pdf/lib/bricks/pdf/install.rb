require 'open-uri'
require 'digest/md5'
require 'digest/sha1'
require 'fileutils'
require 'tempfile'

# begin
#   cmd = 'which python'
#   unless system cmd
#     puts 'FATAL: python 2.6.1+ must be installed'
#     exit
#   end
# end

module Bricks
  module PDF
    class Install

      # Utility to install library necessary to PDF on unix like machine.
      #
      # To install xhtml2pdf and his dependencies, see PDF::xhtml2pdf in zena/tasks.rb

      include FileUtils::Verbose

      attr_reader :url, :file, :md5, :sha1, :force

      def self.from_url url, opts={}
        tmpf = Tempfile.new('PDF').path
        install_dir = "#{tmpf}_d"
        FileUtils.mkpath(install_dir)
        in_dir(install_dir) do
          puts "INFO: start installation of #{url}"
          self.new url, opts do |install|
            install.download
            install.checksum if install.do_checksum?
            install.deflate
            install.setup
          end
          puts "INFO: end installation of #{url}"
        end
      ensure
        FileUtils.rm(tmpf)
        FileUtils.rmtree(install_dir)
      end

      def self.in_dir(path)
        old_dir = ENV['PWD']
        Dir.chdir(path)
        yield
      ensure
        Dir.chdir(old_dir)
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

    end # Install
  end # PDF
end # Bricks






