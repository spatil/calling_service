class AriEvent
  module ClassMethods

    attr_accessor :client, :logger, :callbacks

    def init(client, opts = {})
      self.client = client
      self.start_collecting_events
      self.callbacks = opts[:callbacks]
    end

    def hangup(channels, bridge = nil)
      if bridge
        begin
          bridge.destroy
        rescue Exception => err
          AriEvent.log('Bridge destroy', err, :error)
        end
      end

      channels.each do |c|
        begin
          c.hangup 
        rescue Exception => err
          AriEvent.log('Channel hangup', err, :error)
        end
      end
    end

    def handle_channel_events(in_channel, out_channel)
      bridge = nil

      channels = [out_channel, in_channel]
      channels.each do |channel|
        channel.on :stasis_end do |e|
          AriEvent.log("Channel #{e.channel.name} left Stasis.")
          AriEvent.hangup(channels, bridge)
        end
      end

      out_channel.on :stasis_start do |outc|
        AriEvent.log('****** Inside OutGoing channel ******')

        in_channel.answer

        AriEvent.exec_callback(:answer, in_channel.caller.number, in_channel.dialplan.exten, in_channel)

        bridge = AriEvent.client.bridges.create(type: 'mixing')
        bridge.add_channel(channel: "#{in_channel.id},#{out_channel.id}")
        #bridge.start_moh()
      end

      out_channel.on :channel_destroyed do |outc|
        AriEvent.log('****** OutGoing channel Hangup******')
        AriEvent.hangup(channels, bridge)
      end
      
    end

    def respond_call(channel)
      channel.ring

      exec_callback(:ring, channel.caller.number, channel.dialplan.exten, channel)
      
      number = "#{channel.dialplan.exten}"
      number =  number[1..-1] unless number.match(/09|08|07[2-9]+/).nil?
      endpoint = "DAHDI/g0/#{number}"
      #endpoint = "SIP/#{channel.dialplan.exten}"

      out_channel = client.channels.originate({
        callerId: channel.caller.number,
        endpoint: endpoint, 
        app: 'callific',
        appArgs: 'dialed'
      })

      AriEvent.handle_channel_events(channel, out_channel)
    end

    def start_collecting_events
      client.on :websocket_open do
        AriEvent.log("Connected !")
      end

      client.on :websocket_close do
        AriEvent.log("Closed !")
      end

      client.on :stasis_start do |e|
        in_channel = e.channel

        AriEvent.log("Channel #{in_channel.id} : Received call from #{in_channel.caller.number} to #{in_channel.dialplan.exten} !")

        if in_channel.caller.number.present? and in_channel.dialplan.exten.present? and in_channel.dialplan.exten.to_s != "s"
          AriEvent.respond_call(in_channel)
        end
      end

      client.on :stasis_end do |e|
        AriEvent.log("Client stasis end")
      end

      client.on :websocket_error do |err|
        puts err.message
        puts err.backtrace
        AriEvent.log('ASTERISK', err, :error)
      end

      client.connect_websocket
    end

    def log(msg, err: nil, type: :debug)
      case type
      when :debug
        logger.debug(msg)
      when :error
        logger.error("*** ERROR : #{msg} ***") if msg

        if(err)
          logger.error(err.message)
          logger.error(err.backtrace)
        end
      else
        logger.info(msg)
      end
    end

    def exec_callback(name, *args)
      if cb = callbacks[name]
        cb.call(*args)
      end
    end
  end

  extend ClassMethods
end
