require_relative 'asterisk/callific_ari'
require 'yaml'
require 'logger'
require 'httparty'
require 'active_support/json'


class Server
  def self.start
    rails_env = (ARGV[0] || "development").to_sym 

    config_file = File.expand_path("../config/asterisk_ari.yml", __FILE__)
    config = YAML.load_file(config_file)[rails_env]
    
    phone_ring = Proc.new do |ext, phone, channel|
      phone = "8793606955" if rails_env == :development
      params = { 
          number: phone,
          channel_id: channel.id, 
          call_state: 'start', 
          extension: ext.to_s.last(4)
      }
      response = HTTParty.post("#{config[:application_url]}/calls/recording", 
        { 
          body: params.to_json, 
          headers: { "X-Auth-Token" => config[:token], "Content-Type" => "application/json" }
        }
      )
      AriEvent.log("Call recording for #{phone}, message: #{response.body}")
      #puts "Ringing #{ext} -> #{phone} -> #{channel.id}"
    end

    phone_answer = Proc.new do |ext, phone, channel|
      #puts "Answer #{ext} -> #{phone} -> #{channel.id}"
    end

    phone_hangup = Proc.new do |ext, phone, channel|
      #puts "Hangup #{ext} -> #{phone} -> #{channel.id}"
      params = { 
          number: phone,
          channel_id: channel.id, 
          call_state: 'end', 
          extension: ext.to_s.last(4)
      }
      response = HTTParty.post("#{config[:application_url]}/calls/recording", 
        { 
          body: params.to_json, 
          headers: { "X-Auth-Token" => config[:token], "Content-Type" => "application/json" }
        }
      )
      AriEvent.log("Call recording for #{phone}, message: #{response.body}")
    end

    @client = CallificAri.new(config_file,  rails_env, {
      callbacks: {
        ring: phone_ring,
        answer: phone_answer,
        hangup: phone_hangup
      }
    }) 

    sleep
  end
end

Server.start
