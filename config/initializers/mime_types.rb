['bin'].each do |ext|
  Mime::Type.register Rack::Mime::MIME_TYPES[".#{ext}"], ext.to_sym
end