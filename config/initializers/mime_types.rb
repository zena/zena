[
  'bin',
  ['jpg', 'jpeg'],
].each do |ext|
  if ext.kind_of?(Array)
    Mime::Type.register Rack::Mime::MIME_TYPES[".#{ext}"], ext.first.to_sym, [], ext[1..-1]
  else
    Mime::Type.register Rack::Mime::MIME_TYPES[".#{ext}"], ext.to_sym
  end
end