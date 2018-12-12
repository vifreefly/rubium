require 'ostruct'
require 'rubium/version'
require 'rubium/browser'

module Rubium
  DEFAULT_PUPPETEER_ARGS = %w(
    --disable-background-networking
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
    --disable-breakpad
    --disable-client-side-phishing-detection
    --disable-default-apps
    --disable-dev-shm-usage
    --disable-extensions
    --disable-features=site-per-process
    --disable-hang-monitor
    --disable-ipc-flooding-protection
    --disable-popup-blocking
    --disable-prompt-on-repost
    --disable-renderer-backgrounding
    --disable-sync
    --disable-translate
    --metrics-recording-only
    --no-first-run
    --safebrowsing-disable-auto-update
    --enable-automation
    --password-store=basic
    --use-mock-keychain
    --hide-scrollbars
    --mute-audio
    --no-sandbox
    --disable-infobars
  ).freeze

  def self.configuration
    @configuration ||= OpenStruct.new
  end

  def self.configure
    yield(configuration)
  end
end
