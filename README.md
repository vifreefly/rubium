# Rubium

Rubium is a handy wrapper around [chrome_remote](https://github.com/cavalle/chrome_remote) gem. It adds browsers instances handling, and some Capybara-like methods. It is very lightweight (200 lines of code in the main `Rubium::Browser` class for now) and doens't use Selenium or Capybara. Consider Rubium as a _very simple_ and _basic_ implementation of [Puppeteer](https://github.com/GoogleChrome/puppeteer) in Ruby language.

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

There are some options which you can provide while creating browser instance:

```ruby
browser = Rubium::Browser.new(
  debugging_port: 9222, # custom debugging port
  headless: false, # Run browser in normal (not headless) mode
  window_size: [1600, 900], # Custom window size
  user_agent: "Some user agent", # Custom user-agent
  proxy_server: "http://1.1.1.1:8080", # Set proxy
)
```

You can provide custom Chrome binary path this way:

```ruby
Rubium.configure do |config|
  config.chrome_path = "/path/to/chrome/binary"
end
```


## Installation
Rubium tested with `2.3.0` Ruby version and up.

Rubium is in the alpha stage (and therefore will have breaking updates in the future), so it's recommended to hard-code latest gem version in your Gemfile, like: `gem 'rubium', '0.1.0'`.

## Contribution
Sure, feel free to fork and add new functionality.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
