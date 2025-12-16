# Rubium

## Description

Rubium is a handy wrapper around [chrome_remote](https://github.com/cavalle/chrome_remote) gem. It adds browsers instances handling, and some Capybara-like methods. It is very lightweight (250 lines of code in the main `Rubium::Browser` class for now) and doens't use Selenium or Capybara. Consider Rubium as a _very simple_ and _basic_ implementation of [Puppeteer](https://github.com/GoogleChrome/puppeteer) in Ruby language.

You can use Rubium as a lightweight alternative to Selenium/Capybara/Watir if you need to perform some operations (like web scraping) using Headless Chromium and Ruby. Of course, the API currently doesn't has a lot of methods to automate browser, but it has the most frequently used and basic ones.

```ruby
require 'rubium'

browser = Rubium::Browser.new
browser.visit("https://github.com/vifreefly/rubium")

# Get current page response as string:
browser.body

# Get current page response as Nokogiri object:
browser.current_response

# Click to the some element (css selector):
browser.click("some selector")

# Get current cookies:
browser.cookies

# Set cookies (Array of hashes):
browser.set_cookies([
  { name: "some_cookie_name", value: "some_cookie_value", domain: ".some-cookie-domain.com" },
  { name: "another_cookie_name", value: "another_cookie_value", domain: ".another-cookie-domain.com" }
])

# Fill in some field:
browser.fill_in("some field selector", "Some text")

# Tells if current response has provided css selector or not. You can
# provide optional `wait:` argument (in seconds) to set the max wait time for the selector:
browser.has_css?("some selector", wait: 1)

# Tells if current response has provided text or not. You can
# provide optional `wait:` argument (in seconds) to set the max wait time for the text:
browser.has_text?("some text")

# Evaluate some JS code on a new tab:
browser.evaluate_on_new_document(File.read "browser_inject.js")

# Evaluate JS code expression:
browser.execute_script("JS code string")

# Access chrome_remote client (instance of ChromeRemote class) directly:
# See more here: https://github.com/cavalle/chrome_remote#using-the-chromeremote-api
browser.client

# Close browser:
browser.close

# Restart browser:
browser.restart!
```

**There are some options** which you can provide while creating browser instance:

```ruby
browser = Rubium::Browser.new(
  debugging_port: 9222,                  # custom debugging port. Default is any available port.
  headless: false,                       # Run browser in normal (not headless) mode. Default is headless.
  window_size: [1600, 900],              # Custom window size. Default is unset.
  user_agent: "Some user agent",         # Custom user-agent.
  proxy_server: "http://1.1.1.1:8080",   # Set proxy.
  extension_code: "Some JS code string", # Inject custom JS code on each page. See above `evaluate_on_new_document`
  cookies: [],                           # Set custom cookies, see above `set_cookies`
  restart_after: 25,                     # Automatically restart browser after N processed requests
  enable_logger: true,                   # Enable logger to log info about processing requests
  max_timeout: 30,                       # How long to wait (in seconds) until page will be fully loaded. Default 60 sec.
  urls_blacklist: ["*some-domain.com*"], # Skip all requests which match provided patterns (wildcard allowed).
  disable_images: true                   # Do not download images.
)
```

Note that for options `user_agent` and `proxy_server` you can provide `lambda` object instead of string:

```ruby
USER_AGENTS = ["Safari", "Mozilla", "IE", "Chrome"]
PROXIES = ["http://1.1.1.1:8080", "http://2.2.2.2:8080", "http://3.3.3.3:8080"]

browser = Rubium::Browser.new(
  user_agent:   -> { USER_AGENTS.sample },
  proxy_server: -> { PROXIES.sample },
  restart_after: 25
)
```

> What for: Chrome doesn't provide an API to change proxies on the fly (after browser has been started). It is possible to set proxy while starting Chrome instance by providing CLI argument only. On the other hand, Rubium allows you to automatically restart browser (`restart_after` option) after N processed requests. On each restart, if options `user_agent` and/or `proxy_server` has lambda format, then lambda will be called to fetch fresh value. Thus it's possible to rotate proxies/user-agents without any much effort.


**You can provide custom Chrome binary** path this way:

```ruby
Rubium.configure do |config|
  config.chrome_path = "/path/to/chrome/binary"
end
```

Common Chrome path example for MacOS:

```ruby
Rubium.configure do |config|
  config.chrome_path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
end
```


## Installation
Rubium tested with `3.1.0` Ruby version and up.

## Contribution
Sure, feel free to fork and add new functionality.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
