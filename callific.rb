require_relative 'asterisk/callific_ari'
require 'yaml'
require 'logger'
require 'httparty'
require 'active_support/json'

RAILS_ENV = :development

class Server
  def self.start
    config_file = File.expand_path("../config/asterisk_ari.yml", __FILE__)
    config = YAML.load_file(config_file)[RAILS_ENV]
    
    phone_ring = Proc.new do |ext, phone, channel|
      phone = "+919923681649"
      params = { 
          number: phone,
          channel_id: channel.id 
      }
      response = HTTParty.post("#{config[:application_url]}/calls/recording", 
        { 
          body: params.to_json, 
          headers: { "X-Auth-Token" => "callific", "Content-Type" => "application/json" }
        }
      )
      AriEvent.log("Call recording for #{phone}, message: #{response.body}")
      #puts "Ringing #{ext} -> #{phone} -> #{channel.id}"
    end

    phone_answer = Proc.new do |ext, phone, channel|
      #puts "Answer #{ext} -> #{phone} -> #{channel.id}"
    end

    @client = CallificAri.new(config_file,  RAILS_ENV, {
      callbacks: {
        ring: phone_ring,
        answer: phone_answer
      }
    }) 

    sleep
  end
end

Server.start
