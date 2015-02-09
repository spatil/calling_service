
require 'active_support/core_ext/object'
require 'asterisk/ari/client'
require_relative 'ari_event'


# Channel Doc : https://wiki.asterisk.org/wiki/display/AST/Asterisk+12+Channels+REST+API

class CallificAri
  attr_accessor :config, :opts

  DEFAULT_CONFIG = {
    url: 'http://127.0.0.1:8088/ari',
    app: 'callific',
    dahdi_dial_params: 'g0',
    audio_format: 'wav' 
  }

  def initialize(config_file, env, opts = {})
    @config = DEFAULT_CONFIG.merge(YAML.load_file(config_file)[env.to_sym])
    @opts = opts

    self.init_ari(@config)
  end

  def init_ari(config)
    Ari.client = Ari::Client.new({
      url: config[:url],
      api_key: "#{config[:user]}:#{config[:password]}",
      app: config[:app]
    })

    AriEvent.init(Ari.client, self.opts)
    AriEvent.logger = Logger.new(config[:log_file] || STDOUT)
  end

  def app_name
    @config[:app]
  end

  #
  # DOC: http://www.bsmdev.com/Reference/Sections/InstallNotes-Asterisk_section-1.23.html
  #
  def format_mobile_endpoint(mobile)
    "DAHDI/#{self.config[:dahdi_dial_params]}/#{mobile}"
  end

  def format_extenstion(extenstion)
    extenstion
    #"SIP/#{extenstion}"
  end

  # generate call(channel) uniq id
  def genreate_channel_id(type = 'call')
    "#{type}_#{Time.now.to_f.to_s.sub!('.', '')}"
  end

  def call(mobile, extenstion, opts = {})
    channel = Ari::Channel.originate({
      endpoint: format_mobile_endpoint(mobile),
      extenstion: format_extenstion(extenstion),
      app: app_name
      #context: 'callific'
      #channelId: genreate_channel_id,
      #callerId: opts[:caller_id] || "USER/#{extenstion}"
    })

    self.record_call(channel.id, opts[:recording]) if opts[:recording]

    channel
  end

  def record_call(channel_id, opts = {})
    Ari::Channel.record({
      channelId: channel_id, 
      filename: opts[:filename] || channel_id,
      format: opts[:audio_format] || config[:audio_format]
    })
  end

  def snoop_call(channel_id)
    Ari::Channel.snoop({
      channelId: channel_id,
      snoopId: genreate_channel_id('snoop'),
      app: config[:app]
    })
  end

end 
