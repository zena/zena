require 'syntax'

class ZafuTokenizer < Syntax::Tokenizer
  def step
    if methods = scan(/<\/?z:[^>]+>/)  
      methods =~ /<(\/?)z:([^> ]+)([^\/>]*)(\/?)>/
      start_group :punct, "<#{$1}z:"
      start_group :ztag, $2
      trailing = $4
      params = $3.strip.split(/ +/)
      params.each do |kv|
        key, value = *(kv.split('='))
        append " "
        start_group :param, key
        append "="
        start_group :value, value
      end
      start_group :punct, "#{trailing}>"
    elsif html = scan(/<\/?[^>]+>/)
      html =~/<\/?([^>]+)>/
      start_group :tag, html
    else
      start_group :normal, scan(/./m)
    end
  end
end
Syntax::SYNTAX['zafu'] = ZafuTokenizer


