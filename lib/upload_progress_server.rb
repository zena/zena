#!/usr/bin/env ruby

require 'rubygems'

require 'daemons'
require 'gem_plugin'
require 'drb'

SERVER_PORT = 2999

options = {
  :app_name   => "upload_progress_server",
  :dir_mode   => :normal,
  :dir        => File.expand_path(File.join(File.dirname(__FILE__), '..', 'log')),
  :mode       => :exec,
  :backtrace  => true,
  :monitor    => false
}

Daemons.run_proc('upload_progress_drb', options) do
  GemPlugin::Manager.instance.load 'mongrel' => GemPlugin::INCLUDE
  DRb.start_service "druby://0.0.0.0:#{SERVER_PORT}", Mongrel::UploadProgress.new
  DRb.thread.join
end  
