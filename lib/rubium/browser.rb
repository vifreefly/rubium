require 'chrome_remote'
require 'nokogiri'
require 'random-port'
require 'cliver'
require 'timeout'
require 'securerandom'

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

    attr_reader  :client, :devtools_url, :pid, :port, :options

    def initialize(options = {})
      @options = options
      create_browser
    end

    def restart!
      close
      create_browser
    end

    def close
      Process.kill("HUP", @pid)
      self.class.running_pids.delete(@pid)
      self.class.ports_pool.release(@port)

      FileUtils.rm_rf(@data_dir) if Dir.exist?(@data_dir)
      @closed = true
    end

    alias_method :destroy_driver!, :close

    def goto(url, wait: 30)
      response = @client.send_cmd "Page.navigate", url: url

      if wait
        Timeout.timeout(wait) { @client.wait_for "Page.loadEventFired" }
      else
        response
      end
    end

    alias_method :visit, :goto

    def body
      response = @client.send_cmd "Runtime.evaluate", expression: 'document.documentElement.outerHTML'
      response.dig("result", "value")
    end

    def current_response
      Nokogiri::HTML(body)
    end

    def has_xpath?(selector, wait: 0)
      timer = 0
      until current_response.at_xpath(selector)
        return false if timer >= wait
        timer += 0.2 and sleep 0.2
      end

      true
    end

    def has_text?(text, wait: 0)
      timer = 0
      until body&.include?(text)
        return false if timer >= wait
        timer += 0.2 and sleep 0.2
      end

      true
    end

    def click(selector)
      @client.send_cmd "Runtime.evaluate", expression: <<~JS
        document.querySelector("#{selector}").click();
      JS
    end

    # https://github.com/cyrus-and/chrome-remote-interface/issues/226#issuecomment-320247756
    # https://stackoverflow.com/a/18937620
    def send_key_on(selector, key)
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

    def fill_in(selector, text)
      execute_script <<~HEREDOC
        document.querySelector("#{selector}").value = "#{text}"
      HEREDOC
    end

    def execute_script(script)
      @client.send_cmd "Runtime.evaluate", expression: script
    end

    private

    def create_browser
      @port = options[:debugging_port] || self.class.ports_pool.acquire
      @data_dir = "/tmp/rubium_profile_#{SecureRandom.hex}"

      chrome_path = Rubium.configuration.chrome_path ||
        Cliver.detect("chromium-browser") ||
        Cliver.detect("google-chrome")
      raise ConfigurationError, "Can't find chrome executable" unless chrome_path

      command = %W(
        #{chrome_path} about:blank
        --remote-debugging-port=#{@port}
        --user-data-dir=#{@data_dir}
      ) + DEFAULT_PUPPETEER_ARGS

      command << "--headless" if ENV["HEADLESS"] != "false" && options[:headless] != false
      command << "--window-size=#{options[:window_size].join(',')}" if options[:window_size]

      if options[:user_agent]
        user_agent = options[:user_agent].respond_to?(:call) ? options[:user_agent].call : options[:user_agent]
        puts "Rubium::Browser: enabled user_agent: #{user_agent}"
        command << "--user-agent=#{user_agent}"
      end

      if options[:proxy_server]
        proxy_server = options[:proxy_server].respond_to?(:call) ? options[:proxy_server].call : options[:proxy_server]
        proxy_server = convert_proxy(proxy_server) unless proxy_server.include?("://")

        puts "Rubium::Browser: enabled proxy_server: #{proxy_server}"
        command << "--proxy-server=#{proxy_server}"
      end

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

      evaluate_on_new_document(options[:extension_code]) if options[:extension_code]
    end

    def convert_proxy(proxy_string)
      ip, port, type, user, password = proxy_string.split(":")
      "#{type}://#{ip}:#{port}"
    end
  end
end
