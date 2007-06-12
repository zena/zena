require "#{File.dirname(__FILE__)}/../../config/environment" # needed to load ActiveRecord::Migrator

namespace :bricks do
  desc "Run the bricks server"
  task :server do
    `bricks`
  end
  
  
  desc "Perform initial setup defined in db/initialize/BRICK. Target brick with BRICK=x"
  task :init => :environment do
    if ENV["BRICK"] && File.exist?(init_path = "db/initialize/#{ENV["BRICK"]}/init.rb")
      require init_path
    else
      puts "please provide target brick with 'BRICK=x'. Brick init file not found (#{init_path})"
    end
  end
end
