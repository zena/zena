= ruby-recaptcha

h2. What

h2. Installing

<pre>
  gem install recaptcha
</pre>

h2. The basics

The ReCaptchaClient abstracts the ReCaptcha API for use in Rails Applications


h2. Demonstration of usage

h3. reCAPTCHA

First, create an account at "ReCaptcha.net":http://www.recaptcha.net.

Get your keys, and make them available as constants in your application. You can do this however you want, but RCC_PUB, RCC_PRIV (for regular reCaptcha) and MH_PUB MH_PRIV (for MailHide) must be set to their respective values (the keys you receive from reCaptcha).

The two common methods of doing this (for Rails applications) are to set these variables in your environment.rb file, or via an environment variable, or in Rails 2.2+, in an initializer.

The ReCaptcha::Client constructor can also take an options hash containing keys thusly:
<pre>
  Recaptcha::Client.new(:rcc_pub=>'some key', :rcc_priv=>'some other key')
</pre>
In recent versions of Rails, you can specify the gem in environment.rb:

<pre>
  config.gem 'ruby-recaptcha'
</pre>

After your keys are configured, and the gem is loaded, include the ReCaptcha::AppHelper module in your ApplicationController: 
<pre>
class ApplicationController < ActionController::Base
  include ReCaptcha::AppHelper
</pre>
 This will mix-in validate_recap method.


Then, in the controller where you want to do the validation, chain validate_recap() into your regular validation:
<pre>
  def create
      @user = User.new(params[:user])
      if validate_recap(params, @user.errors) && @user.save
             ...do stuff...
</pre>

Require and include the view helper in your application_helper: NOTE: require is used here, not gem, not sure why.
<pre>
  include ReCaptcha::ViewHelper
</pre> 

This will mix get_captcha() into your view helper.

Now you can just call <pre>get_captcha()</pre> in your view to insert the requisite widget from ReCaptcha.

To customize theme and tabindex of the widget, you can include an options hash:

<pre>get_captcha(:options => {:theme => 'white', :tabindex => 10})</pre>

See the "reCAPTCHA API Documentation":http://recaptcha.net/apidocs/captcha/ under "Look and Feel Customization" for more information.

h3. Proxy support

If your rails application requires the use of a proxy, set proxy_host into your environment:
<pre>
  ENV['proxy_host']='foo.example.com:8080'
</pre>

h3. Mail Hide

When you mix in ViewHelper as above, you also get <pre> mail_hide(address, contents)</pre>, which you can call in your view thusly:

<pre>
  ...
  <%= mail_hide(user.email) %>
</pre>

Contents defaults to the first few characters of the email address.

h2. Bugs

http://www.bitbucket.org/mml/ruby-recaptcha/issues

h2. Code

Get it "here":http://www.bitbucket.org/mml/ruby-recaptcha

Note the wiki & forum & such there...



h2. License

This code is free to use under the terms of the MIT License.

h2. Contact

Comments are welcome. Send an email to "McClain Looney":mailto:mlooney@gmail.com.

h2. Contributors:

Victor Cosby (test cleanup, additional code to style widget)
<br>
Ronald Schroeter (proxy support suggestion & proto-patch)
<br>
Peter Vandenberk (multi-key support, ssl support, various unit tests, test refactoring)
<br>
Kim Griggs (found long address-newline bug)  
