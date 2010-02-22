require 'yaml'

module Bricks
  module RequirementsValidation
    def requirement_errors(brick, requirements)
      current_stderr = $stderr
      $stderr = StringIO.new
      errors = []
      requirements.each do |k,v|
        case k
        when 'gem'
          v.split(',').each do |name|
            begin
              require name.strip
            rescue LoadError => err
              errors << "'#{name}' missing"
            end
          end
        when 'file'
          v.split(',').each do |name|
            unless File.exist?("#{RAILS_ROOT}/#{name}")
              errors << "'#{name}' missing"
            end
          end
        when 'adapter'
          config = YAML.load_file(File.join(RAILS_ROOT, 'config', 'database.yml'))
          adapter = config[RAILS_ENV]['adapter']
          unless v.split(',').map(&:strip).include?(adapter)
            errors << "'#{adapter}' not supported"
          end
        end
      end
      $stderr = current_stderr
      errors.empty? ? nil : errors
    end

    def config_for_active_bricks
      if File.exist?("#{RAILS_ROOT}/config/bricks.yml")
        raw_config = YAML.load_file("#{RAILS_ROOT}/config/bricks.yml")[RAILS_ENV] || {}
      else
        raw_config = YAML.load_file("#{Zena::ROOT}/config/bricks.yml")[RAILS_ENV] || {}
      end
      config = {}

      raw_config.each do |brick, opts|
        if opts.kind_of?(Hash)
          next unless opts['switch'] == true
          if activation = opts.delete('activate_if')
            if errors = requirement_errors(brick, activation)
              if defined?(ActiveRecord::Base) && logger = ActiveRecord::Base.logger
                ActiveRecord::Base.logger.warn "'#{brick}' not activated: #{errors.join(', ')}"
              end
              puts "'#{brick}' not activated: #{errors.join(', ')}" if RAILS_ENV == 'development'
            end
          end
          config[brick] = opts unless errors
        else
          if opts == true
            config[brick] = {}
          end
        end
      end
      config
    end

    def runtime_requirement_errors(brick_name)
      return ["'#{brick_name}' was not activated."] unless opts = Bricks::CONFIG[brick_name]
      if run_requirements = opts.delete('run_if')
        return requirement_errors(brick_name, run_requirements)
      end
      nil
    end
  end
end