require 'chrome_remote'
require 'random-port'
require 'cliver'

at_exit do
  Rubium::Browser.running_pids.each { |pid| Process.kill("HUP", pid) ; puts "Killed #{pid}" }
end

module Rubium
  class Browser
    class ConfigurationError < StandardError; end

    class << self
      def ports_pool
        @pool ||= RandomPort::Pool.new
      end

      def running_pids
        @running_pids ||= []
      end
    end

    attr_reader  :client, :devtools_url, :pid, :port

    def initialize(debugging_port: nil, proxy_server: nil, user_agent: nil, headless: true, window_size: nil, user_data_dir: nil)
      @port = debugging_port || self.class.ports_pool.acquire
      @data_dir = "/tmp/chrome-testing#{rand(1111..32423423)}" # TODO

      # @global_sleep = Rubium.configuration.global_sleep || 0

      chrome_path = Rubium.configuration.chrome_path ||
        Cliver.detect("chromium-browser") ||
        Cliver.detect("google-chrome")
      raise ConfigurationError, "Can't find chrome executable" unless chrome_path

      command = %W(
        #{chrome_path} about:blank
        --remote-debugging-port=#{@port}
        --user-data-dir=#{@data_dir}
      ) + DEFAULT_PUPPETEER_ARGS

      command << "--headless" if ENV["HEADLESS"] != "false" && headless
      command << "--user-agent=#{user_agent}" if user_agent
      command << "--window-size=#{window_size.join(',')}" if window_size
      command << "--proxy-server=#{proxy_server}" if proxy_server

      @pid = spawn(*command, [:out, :err] => "/dev/null")
      self.class.running_pids << @pid
      @closed = false

      begin
        sleep 0.5
        @client = ChromeRemote.client(port: @port)
      rescue => e
        puts "Error connection: #{e.inspect}"
        retry
      end

      @devtools_url = "http://localhost:#{@port}/"

      # https://github.com/GoogleChrome/puppeteer/blob/master/lib/Page.js
      @client.send_cmd "Target.setAutoAttach", autoAttach: true, waitForDebuggerOnStart: false
      @client.send_cmd "Network.enable"
      @client.send_cmd "Page.enable"
    end

    def close
      # @client.send_cmd "Browser.close" # Didn't work in some cases
      Process.kill("HUP", @pid)
      self.class.running_pids.delete(@pid)
      self.class.ports_pool.release(@port)

      FileUtils.rm_rf(@data_dir) if Dir.exist?(@data_dir)
      @closed = true
    end
    alias_method :destroy_driver!, :close

    def goto(url, wait: true)
      # sleep rand @global_sleep

      response = @client.send_cmd "Page.navigate", url: url

      if wait
        @client.wait_for "Page.loadEventFired"
        # @client.wait_for "Page.frameStoppedLoading", frameId: response["frameId"]
      else
        response
      end
    end

    alias_method :visit, :goto

    def body
      # add evaluate method
      response = @client.send_cmd "Runtime.evaluate", expression: 'document.documentElement.outerHTML'
      response.dig("result", "value")
    end

    def current_response(type = :html)
      require 'nokogiri'
      ::Nokogiri::HTML(body)
    end

    def has_xpath?(selector, wait: 0)
      timer = 0
      until current_response.at_xpath(selector)
        return false if timer >= wait
        sleep 0.2
      end

      true
    end

    def has_text?(text, wait: 0)
      # body.match?(/#{text}/)

      timer = 0
      until body.include?(text)
        return false if timer >= wait
        sleep 0.2
      end

      true
    end

    def click(selector)
      # sleep rand @global_sleep

      @client.send_cmd "Runtime.evaluate", expression: <<~JS
        document.querySelector("#{selector}").click();
      JS
    end

    # https://github.com/cyrus-and/chrome-remote-interface/issues/226#issuecomment-320247756
    # https://stackoverflow.com/a/18937620
    def send_key_on(selector, key = 13)
      # sleep rand @global_sleep

      @client.send_cmd "Runtime.evaluate", expression: <<~JS
        document.querySelector("#{selector}").dispatchEvent(
          new KeyboardEvent("keydown", {
            bubbles: true, cancelable: true, keyCode: #{key}
          })
        );
      JS
    end

    # https://github.com/GoogleChrome/puppeteer/blob/master/lib/Page.js#L784
    # https://stackoverflow.com/questions/46113267/how-to-use-evaluateonnewdocument-and-exposefunction
    # https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-addScriptToEvaluateOnNewDocument
    def evaluate_on_new_document(script)
      @client.send_cmd "Page.addScriptToEvaluateOnNewDocument", source: script
    end

    def cookies
      response = @client.send_cmd "Network.getCookies"
      response["cookies"]
    end
  end
end
