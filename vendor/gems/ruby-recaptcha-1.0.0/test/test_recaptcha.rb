require File.dirname(__FILE__) + '/test_helper.rb'
require 'rubygems'
gem 'mocha'
require 'mocha'
gem 'rails'

module ReCaptcha
  module ViewHelper
    def self.define_public_key
      class_eval "RCC_PUB = 'foo'"
    end
    def self.define_private_key
      class_eval "RCC_PRIV = 'bar'"
    end
    def self.undefine_public_key
      remove_const :RCC_PUB
    end
    def self.undefine_private_key
      remove_const :RCC_PRIV
    end
  end
  module AppHelper
    def self.define_public_key
      class_eval "RCC_PUB = 'foo'"
    end
    def self.define_private_key
      class_eval "RCC_PRIV = 'bar'"
    end
    def self.undefine_public_key
      remove_const :RCC_PUB
    end
    def self.undefine_private_key
      remove_const :RCC_PRIV
    end
    public :validate_recap
  end
end

class TestRecaptcha < Test::Unit::TestCase
  class ViewFixture
    PRIVKEY='6LdnAQAAAAAAAPYLVPwVvR7Cy9YLhRQcM3NWsK_C'
    PUBKEY='6LdnAQAAAAAAAKEk59yjuP3csGEeDmdj__7cyMtY'
    include ReCaptcha::ViewHelper
    # views in Rails "inherit" the controller's session...
    def session
      @session ||= {}
    end
  end
  class ControllerFixture
    include ReCaptcha::AppHelper
    attr_reader :request
    # all Rails controllers have a session...
    def session
      @session ||= {}
    end
    def initialize()
      @request = mock()
      @request.stubs(:remote_ip).returns('0.0.0.0') # this will skip the actual captcha validation...
      @request
    end
    include Mocha::Standalone
  end

  def setup
    @vf = ViewFixture.new
    @cf = ControllerFixture.new
  end

  def test_encrypt
    mhc = ReCaptcha::MHClient.new('01S1TOX9aibKxfC9oJlp8IeA==', 'deadbeefdeadbeefdeadbeefdeadbeef')
    z =mhc.encrypt('x@example.com')
    assert_equal 'wBG7nOgntKqWeDpF9ucVNQ==', z
    z =mhc.encrypt('johndoe@example.com')
    assert_equal 'whWIqk0r4urZ-3S7y7uSceC9_ECd3hpAGy71E2o0HpI=', z
  end
  def test_encrypt_long
    mhc = ReCaptcha::MHClient.new('01S1TOX9aibKxfC9oJlp8IeA==', 'deadbeefdeadbeefdeadbeefdeadbeef')
    z =mhc.encrypt('averylongemailaddressofmorethan32cdharactersx@example.com')
    assert_equal "q-0LLVT2bIxWbFpfLfpNhJAGadkfWXVk4hAxSlVaLrdnXrsB1NKNubavS5N-7PBued3K531vifN6NB3iz3W7qQ==",z
    z =mhc.encrypt('johndoe@example.com')
    assert_equal 'whWIqk0r4urZ-3S7y7uSceC9_ECd3hpAGy71E2o0HpI=', z
  end

  def test_nil_challenge
    client = new_client
    estub = stub_everything('errors')
    client.validate('abc', nil, 'foo', estub)

  end

  def test_constructor
    client = new_client('abc', 'def', true)
    expected= <<-EOF
    <script type=\"text/javascript\" src=\"https://api-secure.recaptcha.net/challenge?k=abc\"> </script>\n      <noscript>\n      <iframe src=\"https://api-secure.recaptcha.net/noscript?k=abc\"\n      height=\"300\" width=\"500\" frameborder=\"0\"></iframe><br>\n      <textarea name=\"recaptcha_challenge_field\" rows=\"3\" cols=\"40\">\n      </textarea>\n      <input type=\"hidden\" name=\"recaptcha_response_field\" \n      value=\"manual_challenge\">\n      </noscript>
    EOF
    assert_equal expected.strip, client.get_challenge.strip
    client = new_client
    expected= <<-EOF
    <script type=\"text/javascript\" src=\"http://api.recaptcha.net/challenge?k=abc\"> </script>\n      <noscript>\n      <iframe src=\"http://api.recaptcha.net/noscript?k=abc\"\n      height=\"300\" width=\"500\" frameborder=\"0\"></iframe><br>\n      <textarea name=\"recaptcha_challenge_field\" rows=\"3\" cols=\"40\">\n      </textarea>\n      <input type=\"hidden\" name=\"recaptcha_response_field\" \n      value=\"manual_challenge\">\n      </noscript>
    EOF
    assert_equal expected.strip, client.get_challenge.strip
    client = new_client
    expected= <<-EOF
    <script type=\"text/javascript\" src=\"http://api.recaptcha.net/challenge?k=abc\"> </script>\n      <noscript>\n      <iframe src=\"http://api.recaptcha.net/noscript?k=abc\"\n      height=\"300\" width=\"500\" frameborder=\"0\"></iframe><br>\n      <textarea name=\"recaptcha_challenge_field\" rows=\"3\" cols=\"40\">\n      </textarea>\n      <input type=\"hidden\" name=\"recaptcha_response_field\" \n      value=\"manual_challenge\">\n      </noscript>
    EOF
    assert_equal expected.strip, client.get_challenge.strip
  end

  def test_constructor_with_recaptcha_options
    # "Look and Feel Customization" per http://recaptcha.net/apidocs/captcha/
    client = new_client
    expected= <<-EOF
    <script type=\"text/javascript\">\nvar RecaptchaOptions = { theme : \"white\", tabindex : 10};\n</script>\n      <script type=\"text/javascript\" src=\"http://api.recaptcha.net/challenge?k=abc&error=somerror\"> </script>\n      <noscript>\n      <iframe src=\"http://api.recaptcha.net/noscript?k=abc&error=somerror\"\n      height=\"300\" width=\"500\" frameborder=\"0\"></iframe><br>\n      <textarea name=\"recaptcha_challenge_field\" rows=\"3\" cols=\"40\">\n      </textarea>\n      <input type=\"hidden\" name=\"recaptcha_response_field\" \n      value=\"manual_challenge\">\n      </noscript>
    EOF
    assert_equal expected.strip, client.get_challenge('somerror', :options => {:theme => 'white', :tabindex => 10}).strip
  end

  def test_validate_fails
    badwords_resp="false\r\n360 incorrect-captcha-sol"
    err_stub=mock()
    err_stub.expects(:add_to_base).with("Captcha failed.")
    stub_proxy=mock('proxy')
    stub_http = mock('http mock')
    stub_proxy.expects(:start).with('api-verify.recaptcha.net').returns(stub_http)
    stub_http.expects(:post).with('/verify', 'privatekey=def&remoteip=localhost&challenge=abc&response=def', {'Content-Type' => 'application/x-www-form-urlencoded'}).returns(['foo', badwords_resp])
    Net::HTTP.expects(:Proxy).returns(stub_proxy)
    client = new_client
    assert !client.validate('localhost', 'abc', 'def', err_stub)
  end
  def test_validate_good
    goodwords_resp="true\r\nsuccess"
    err_stub=mock()
    stub_proxy=mock('proxy')
    stub_http = mock('http mock')
    stub_proxy.expects(:start).with('api-verify.recaptcha.net').returns(stub_http)
    stub_http.expects(:post).with('/verify', 'privatekey=def&remoteip=localhost&challenge=abc&response=def', {'Content-Type' => 'application/x-www-form-urlencoded'}).returns(['foo', goodwords_resp])
    Net::HTTP.expects(:Proxy).with(nil, nil).returns(stub_proxy)
    client = new_client
    assert client.validate('localhost', 'abc', 'def', err_stub)
  end
  def test_validate_good_proxy
    ENV['proxy_host']='fubar:8080'
    goodwords_resp="true\r\nsuccess"
    err_stub=mock()
    stub_proxy=mock('proxy')
    stub_http = mock('http mock')
    stub_proxy.expects(:start).with('api-verify.recaptcha.net').returns(stub_http)
    stub_http.expects(:post).with('/verify', 'privatekey=def&remoteip=localhost&challenge=abc&response=def', {'Content-Type' => 'application/x-www-form-urlencoded'}).returns(['foo', goodwords_resp])
    Net::HTTP.expects(:Proxy).with('fubar', '8080').returns(stub_proxy)
    client = new_client
    assert client.validate('localhost', 'abc', 'def', err_stub)
    ENV['proxy_host']='fubar'
    err_stub=mock()
    stub_proxy=mock('proxy')
    stub_http = mock('http mock')
    stub_proxy.expects(:start).with('api-verify.recaptcha.net').returns(stub_http)
    stub_http.expects(:post).with('/verify', 'privatekey=def&remoteip=localhost&challenge=abc&response=def', {'Content-Type' => 'application/x-www-form-urlencoded'}).returns(['foo', goodwords_resp])
    Net::HTTP.expects(:Proxy).with('fubar', nil).returns(stub_proxy)
    client = new_client
    assert client.validate('localhost', 'abc', 'def', err_stub)
  end

  #
  # unit tests for the get_captcha() ViewHelper method
  #

  def test_get_captcha_fails_without_key_constants
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PRIV)
    assert_raise NameError do
      @vf.get_captcha
    end
  end
  def test_get_captcha_fails_without_public_key_constant
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PRIV)
    ReCaptcha::ViewHelper.define_private_key
    assert ReCaptcha::ViewHelper.const_defined?(:RCC_PRIV)
    assert_raise NameError do
      @vf.get_captcha
    end
    ReCaptcha::ViewHelper.undefine_private_key
  end
  def test_get_captcha_fails_without_private_key_constant
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PRIV)
    ReCaptcha::ViewHelper.define_public_key
    assert ReCaptcha::ViewHelper.const_defined?(:RCC_PUB)
    assert_raise NameError do
      @vf.get_captcha
    end
    ReCaptcha::ViewHelper.undefine_public_key
  end
  def test_get_captcha_succeeds_with_key_constants
    mock_client = mock('client')
    ReCaptcha::Client.expects(:new).returns(mock_client)
    mock_client.expects(:get_challenge).with('', {})
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PRIV)
    ReCaptcha::ViewHelper.define_public_key
    ReCaptcha::ViewHelper.define_private_key
    assert ReCaptcha::ViewHelper.const_defined?(:RCC_PUB)
    assert ReCaptcha::ViewHelper.const_defined?(:RCC_PRIV)
    assert_nothing_raised do
      @vf.get_captcha
    end
    ReCaptcha::ViewHelper.undefine_public_key
    ReCaptcha::ViewHelper.undefine_private_key
  end
  def test_get_captcha_succeeds_without_key_constants_but_with_options
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::ViewHelper.const_defined?(:RCC_PRIV)
    assert_nothing_raised do
      @vf.get_captcha(:rcc_pub => 'foo', :rcc_priv => 'bar')
    end
  end
  def test_get_captcha_is_correct_with_constants_and_with_options
    expected= <<-EOF
    <script type=\"text/javascript\" src=\"http://api.recaptcha.net/challenge?k=%s\"> </script>\n      <noscript>\n      <iframe src=\"http://api.recaptcha.net/noscript?k=%s\"\n      height=\"300\" width=\"500\" frameborder=\"0\"></iframe><br>\n      <textarea name=\"recaptcha_challenge_field\" rows=\"3\" cols=\"40\">\n      </textarea>\n      <input type=\"hidden\" name=\"recaptcha_response_field\" \n      value=\"manual_challenge\">\n      </noscript>
    EOF
    # first, with constants
    ReCaptcha::ViewHelper.define_public_key  # 'foo'
    ReCaptcha::ViewHelper.define_private_key # 'bar'
    actual = @vf.get_captcha
    assert_equal(((expected % ['foo', 'foo']).strip), actual.strip)
    ReCaptcha::ViewHelper.undefine_public_key
    ReCaptcha::ViewHelper.undefine_private_key
    # next, with options
    actual = @vf.get_captcha(:rcc_pub => 'foobar', :rcc_priv => 'blegga')
    assert_equal(((expected % ['foobar', 'foobar']).strip), actual.strip)
  end

  #
  # unit tests for the validate_recap() AppHelper method
  #

  def test_validate_recap_fails_without_key_constants
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PRIV)
    assert_raise NameError do
      @cf.validate_recap({}, {})
    end
  end
  def test_validate_recap_fails_without_public_key_constant
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PRIV)
    ReCaptcha::AppHelper.define_private_key
    assert ReCaptcha::AppHelper.const_defined?(:RCC_PRIV)
    assert_raise NameError do
      @cf.validate_recap({}, {})
    end
    ReCaptcha::AppHelper.undefine_private_key
  end
  def test_validate_recap_fails_without_private_key_constant
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PRIV)
    ReCaptcha::AppHelper.define_public_key
    assert ReCaptcha::AppHelper.const_defined?(:RCC_PUB)
    assert_raise NameError do
      @cf.validate_recap({}, {})
    end
    ReCaptcha::AppHelper.undefine_public_key
  end
  def test_validate_recap_succeeds_with_key_constants
    e = mock('errors')
    e.expects(:add_to_base).with('Captcha failed.')
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PRIV)
    ReCaptcha::AppHelper.define_public_key
    ReCaptcha::AppHelper.define_private_key
    assert ReCaptcha::AppHelper.const_defined?(:RCC_PUB)
    assert ReCaptcha::AppHelper.const_defined?(:RCC_PRIV)
    assert_nothing_raised do
      @cf.validate_recap({}, e)
    end
    ReCaptcha::AppHelper.undefine_public_key
    ReCaptcha::AppHelper.undefine_private_key
  end
  def test_validate_recap_succeeds_without_key_constants_but_with_options
    mock = mock('client')
    ReCaptcha::Client.expects(:new).returns(mock)
    mock.expects(:validate).with('0.0.0.0', nil, nil, {}).returns(true)
    mock.expects(:last_error)
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PUB)
    assert !ReCaptcha::AppHelper.const_defined?(:RCC_PRIV)
    @cf.validate_recap({}, {}, :rcc_pub => 'foo', :rcc_priv => 'bar')
  end
  def test_validate_recap_is_correct_with_constants_and_with_options
    # first, with constants
    e = mock('errors')
    mock = mock('client')
    ReCaptcha::Client.expects(:new).returns(mock).times(2)
    mock.expects(:validate).with('0.0.0.0', nil,  nil, {}).returns(true)
    mock.expects(:last_error).times(2)
    ReCaptcha::AppHelper.define_public_key  # 'foo'
    ReCaptcha::AppHelper.define_private_key # 'bar'
    assert @cf.validate_recap({}, {})
    ReCaptcha::AppHelper.undefine_public_key
    ReCaptcha::AppHelper.undefine_private_key
    # next, with options
    mock.expects(:validate).with('0.0.0.0', nil,  nil, e).returns(true)
    assert @cf.validate_recap({}, e, {:rcc_pub => 'foobar', :rcc_priv => 'blegga'})
  end

  #
  # unit tests for HTTP/HTTPS-variants of get_captcha() method
  #

  def test_get_captcha_uses_http_without_options
    expected= <<-EOF
    <script type=\"text/javascript\" src=\"http://api.recaptcha.net/challenge?k=%s\"> </script>\n      <noscript>\n      <iframe src=\"http://api.recaptcha.net/noscript?k=%s\"\n      height=\"300\" width=\"500\" frameborder=\"0\"></iframe><br>\n      <textarea name=\"recaptcha_challenge_field\" rows=\"3\" cols=\"40\">\n      </textarea>\n      <input type=\"hidden\" name=\"recaptcha_response_field\" \n      value=\"manual_challenge\">\n      </noscript>
    EOF
    actual = @vf.get_captcha(:rcc_pub => 'foobar', :rcc_priv => 'blegga')
    assert_equal(((expected % ['foobar', 'foobar']).strip), actual.strip)
  end
  def test_get_captcha_uses_https_with_options_true
    expected= <<-EOF
    <script type=\"text/javascript\" src=\"https://api-secure.recaptcha.net/challenge?k=%s\"> </script>\n      <noscript>\n      <iframe src=\"https://api-secure.recaptcha.net/noscript?k=%s\"\n      height=\"300\" width=\"500\" frameborder=\"0\"></iframe><br>\n      <textarea name=\"recaptcha_challenge_field\" rows=\"3\" cols=\"40\">\n      </textarea>\n      <input type=\"hidden\" name=\"recaptcha_response_field\" \n      value=\"manual_challenge\">\n      </noscript>
    EOF
    actual = @vf.get_captcha(:rcc_pub => 'foobar', :rcc_priv => 'blegga', :ssl => true)
    assert_equal(((expected % ['foobar', 'foobar']).strip), actual.strip)
  end
  def test_get_captcha_uses_http_with_options_false
    expected= <<-EOF
    <script type=\"text/javascript\" src=\"http://api.recaptcha.net/challenge?k=%s\"> </script>\n      <noscript>\n      <iframe src=\"http://api.recaptcha.net/noscript?k=%s\"\n      height=\"300\" width=\"500\" frameborder=\"0\"></iframe><br>\n      <textarea name=\"recaptcha_challenge_field\" rows=\"3\" cols=\"40\">\n      </textarea>\n      <input type=\"hidden\" name=\"recaptcha_response_field\" \n      value=\"manual_challenge\">\n      </noscript>
    EOF
    actual = @vf.get_captcha(:rcc_pub => 'foobar', :rcc_priv => 'blegga', :ssl => false)
    assert_equal(((expected % ['foobar', 'foobar']).strip), actual.strip)
  end

  private

  def new_client(pubkey='abc', privkey='def', ssl=false)
    ReCaptcha::Client.new(pubkey, privkey, ssl)
  end
end
