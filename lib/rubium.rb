require 'ostruct'
require 'rubium/version'
require 'rubium/browser'

module Rubium
  DEFAULT_PUPPETEER_ARGS = %w(
    --disable-field-trial-config
    --disable-background-networking
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
    --disable-breakpad
    --no-default-browser-check
    --disable-dev-shm-usage
    --disable-features=AcceptCHFrame,AvoidUnnecessaryBeforeUnloadCheckSync,DestroyProfileOnBrowserClose,DialMediaRouteProvider,GlobalMediaControls,HttpsUpgrades,LensOverlay,MediaRouter,PaintHolding,ThirdPartyStoragePartitioning,Translate,AutoDeElevate,RenderDocument,OptimizationHints
    --enable-features=CDPScreenshotNewSurface
    --disable-hang-monitor
    --disable-prompt-on-repost
    --disable-renderer-backgrounding
    --force-color-profile=srgb
    --no-first-run
    --password-store=basic
    --use-mock-keychain
    --no-service-autorun
    --export-tagged-pdf
    --disable-search-engine-choice-screen
    --edge-skip-compat-layer-relaunch
    --disable-infobars
    --disable-search-engine-choice-screen
    --disable-sync
    --disable-blink-features=AutomationControlled
    --enable-unsafe-swiftshader
    --no-sandbox
    --force-webrtc-ip-handling-policy=disable_non_proxied_udp
    --webrtc-ip-handling-policy=disable_non_proxied_udp
  ).freeze

  def self.configuration
    @configuration ||= OpenStruct.new
  end

  def self.configure
    yield(configuration)
  end
end
