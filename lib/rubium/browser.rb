require 'chrome_remote'
require 'nokogiri'
require 'random-port'
require 'cliver'
require 'timeout'
require 'securerandom'
require 'logger'
require 'fileutils'

at_exit do
  Rubium::Browser.running_pids.each { |pid| Process.kill("HUP", pid) }
end

module Rubium
  class Browser
    class ConfigurationError < StandardError; end

    MAX_CONNECT_WAIT_TIME = 6
    MAX_DEFAULT_TIMEOUT = 60

    class << self
      def ports_pool
        @pool ||= RandomPort::Pool.new
      end

      def running_pids
        @running_pids ||= []
      end
    end

    attr_reader  :client, :devtools_url, :pid, :port, :options, :processed_requests_count, :logger

    def initialize(options = {})
      @options = options

      if @options[:enable_logger]
        @logger = Logger.new(STDOUT)
        @logger.progname = self.class.to_s
      end

      create_browser
    end

    def restart!
      logger.info "Restarting..." if options[:enable_logger]

      close
      create_browser
    end

    def close
      if closed?
        logger.info "Browser already has been closed" if options[:enable_logger]
      else
        Process.kill("HUP", @pid)
        self.class.running_pids.delete(@pid)
        self.class.ports_pool.release(@port)

        # Delete temp profile directory, if there is no custom one
        unless options[:data_dir]
          FileUtils.rm_rf(@data_dir) if Dir.exist?(@data_dir)
        end

        logger.info "Closed browser" if options[:enable_logger]
        @closed = true
      end
    end

    alias_method :destroy_driver!, :close

    def closed?
      @closed
    end

    def goto(url, wait: options[:max_timeout] || MAX_DEFAULT_TIMEOUT)
      logger.info "Started request: #{url}" if options[:enable_logger]
      if options[:restart_after] && processed_requests_count >= options[:restart_after]
        restart!
      end

      response = @client.send_cmd "Page.navigate", url: url

      # By default, after Page.navigate we should wait till page will load completely
      # using Page.loadEventFired. But on some websites with Ajax navigation, Page.loadEventFired
      # will stuck forever. In this case you can provide `wait: false` option to skip waiting.
      if wait != false
        # https://chromedevtools.github.io/devtools-protocol/tot/Page#event-frameStoppedLoading
        Timeout.timeout(wait) do
          @client.wait_for do |event_name, event_params|
            event_name == "Page.frameStoppedLoading" && event_params["frameId"] == response["frameId"]
          end
        end
      end

      @processed_requests_count += 1
      logger.info "Finished request: #{url}" if options[:enable_logger]
    end

    alias_method :visit, :goto

    def body
      response = @client.send_cmd "Runtime.evaluate", expression: 'document.documentElement.outerHTML'
      response.dig("result", "value")
    end

    def current_response
      Nokogiri::HTML(body)
    end

    def has_xpath?(path, wait: 0)
      timer = 0
      until current_response.at_xpath(path)
        return false if timer >= wait
        timer += 0.2 and sleep 0.2
      end

      true
    end

    def has_css?(selector, wait: 0)
      timer = 0
      until current_response.at_css(selector)
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
      @client.send_cmd "Runtime.evaluate", expression: <<~js
        document.querySelector("#{selector}").click();
      js
    end

    # https://github.com/cyrus-and/chrome-remote-interface/issues/226#issuecomment-320247756
    # https://stackoverflow.com/a/18937620
    def send_key_on(selector, key)
      @client.send_cmd "Runtime.evaluate", expression: <<~js
        document.querySelector("#{selector}").dispatchEvent(
          new KeyboardEvent("keydown", {
            bubbles: true, cancelable: true, keyCode: #{key}
          })
        );
      js
    end

    # https://github.com/GoogleChrome/puppeteer/blob/master/lib/Page.js#L784
    # https://stackoverflow.com/questions/46113267/how-to-use-evaluateonnewdocument-and-exposefunction
    # https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-addScriptToEvaluateOnNewDocument
    def evaluate_on_new_document(script)
      @client.send_cmd "Page.addScriptToEvaluateOnNewDocument", source: script
    end

    ###

    def cookies
      response = @client.send_cmd "Network.getCookies"
      response["cookies"]
    end

    # https://chromedevtools.github.io/devtools-protocol/tot/Network#method-setCookies
    def set_cookies(cookies)
      @client.send_cmd "Network.setCookies", cookies: cookies
    end

    ###

    def fill_in(selector, text)
      execute_script <<~js
        document.querySelector("#{selector}").value = "#{text}"
      js
    end

    def execute_script(script)
      @client.send_cmd "Runtime.evaluate", expression: script
    end

    private

    def create_browser
      @processed_requests_count = 0

      @port = options[:debugging_port] || self.class.ports_pool.acquire

      @data_dir = options[:data_dir] || "/tmp/rubium_profile_#{SecureRandom.hex}"

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
        command << "--user-agent=#{user_agent}"
      end

      if options[:proxy_server]
        proxy_server = options[:proxy_server].respond_to?(:call) ? options[:proxy_server].call : options[:proxy_server]
        proxy_server = convert_proxy(proxy_server) unless proxy_server.include?("://")
        command << "--proxy-server=#{proxy_server}"
      end

      @pid = spawn(*command, [:out, :err] => "/dev/null")
      self.class.running_pids << @pid
      @closed = false

      counter = 0
      begin
        counter += 0.2 and sleep 0.2
        @client = ChromeRemote.client(port: @port)
      rescue Errno::ECONNREFUSED => e
        counter < MAX_CONNECT_WAIT_TIME ? retry : raise(e)
      end

      @devtools_url = "http://localhost:#{@port}/"

      # https://github.com/GoogleChrome/puppeteer/blob/master/lib/Page.js
      @client.send_cmd "Target.setAutoAttach", autoAttach: true, waitForDebuggerOnStart: false
      @client.send_cmd "Network.enable"
      @client.send_cmd "Page.enable"

      evaluate_on_new_document(options[:extension_code]) if options[:extension_code]

      set_cookies(options[:cookies]) if options[:cookies]

      if options[:urls_blacklist] || options[:disable_images]
        urls = []

        if options[:urls_blacklist]
          urls += options[:urls_blacklist]
        end

        if options[:disable_images]
          urls += %w(jpg jpeg png gif swf svg tif).map { |ext| ["*.#{ext}", "*.#{ext}?*"] }.flatten
          urls << "data:image*"
        end

        @client.send_cmd "Network.setBlockedURLs", urls: urls
      end


      logger.info "Opened browser" if options[:enable_logger]
    end

    def convert_proxy(proxy_string)
      ip, port, type, user, password = proxy_string.split(":")
      "#{type}://#{ip}:#{port}"
    end
  end
end
