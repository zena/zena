# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false
config.action_view.debug_rjs                         = true

# Do not change this setting or zafu won't work and EagerPath loader
# will glob *ALL* content in sites directory and try to use it as a template !!!
config.action_view.cache_template_loading            = false

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false
