
# All models can use attr_public
ActiveRecord::Base.send :include, Zena::Use::PublicAttributes
ActiveRecord::Base.send :include, Zena::Use::Zafu
ActiveRecord::Base.send :include, Zena::Use::NodeQueryFinders
ActiveRecord::Base.send :include, Zena::Use::Relations
ActiveRecord::Base.send :include, Zena::Use::FindHelpers
ActiveRecord::Base.send :include, Zena::Acts::Secure
ActiveRecord::Base.send :include, Zena::Acts::Multiversion

ActiveRecord::Base.send :use_find_helpers # find helpers for all models

Bricks::Patcher.load_bricks