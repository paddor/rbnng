# frozen_string_literal: true

module NNG
  module Socket
    class Base
      alias_method :send_msg, :send
      alias_method :get_msg, :receive
      alias_method :_listen, :listen
      alias_method :_dial, :dial


      def raw?
        @raw
      end


      def listen(url)
        _listen(url)
        (@urls ||= []) << url
        self
      end

      def dial(url)
        _dial(url)
        (@urls ||= []) << url
        self
      end

      def urls
        (@urls ||= []).dup.freeze
      end


      def name
        get_opt_string('socket-name')
      end

      def name=(value)
        set_opt_string('socket-name', value)
      end


      def recv_timeout
        get_opt_ms('recv-timeout')
      end

      def recv_timeout=(ms)
        set_opt_ms('recv-timeout', ms.to_i)
      end

      def send_timeout
        get_opt_ms('send-timeout')
      end

      def send_timeout=(ms)
        set_opt_ms('send-timeout', ms.to_i)
      end

      def recv_buffer
        get_opt_int('recv-buffer')
      end

      def recv_buffer=(n)
        set_opt_int('recv-buffer', n.to_i)
      end

      def send_buffer
        get_opt_int('send-buffer')
      end

      def send_buffer=(n)
        set_opt_int('send-buffer', n.to_i)
      end

      def recv_max_size
        get_opt_size('recv-size-max')
      end

      def recv_max_size=(n)
        set_opt_size('recv-size-max', n.to_i)
      end

      def reconnect_time
        min_ms = get_opt_ms('reconnect-time-min')
        max_ms = get_opt_ms('reconnect-time-max')
        (min_ms / 1000.0)..(max_ms / 1000.0)
      end

      def reconnect_time=(range)
        set_opt_ms('reconnect-time-min', (range.begin * 1000).to_i)
        set_opt_ms('reconnect-time-max', (range.end * 1000).to_i)
      end

      def protocol_name
        get_opt_string('protocol-name')
      end

      def peer_name
        get_opt_string('peer-name')
      end
    end
  end
end
