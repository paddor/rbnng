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


      def listen(url, cert: nil, key: nil, ca: nil, verify: false, server_name: nil)
        if cert || key || ca
          cert_pem = cert ? TLS.coerce_pem(cert) : nil
          key_pem  = key  ? TLS.coerce_pem(key)  : nil
          ca_pem   = ca   ? TLS.coerce_pem(ca)   : nil
          _listen_tls(url, cert_pem, key_pem, ca_pem, verify, server_name)
        else
          _listen(url)
        end
        (@urls ||= []) << url
        self
      end

      def dial(url, cert: nil, key: nil, ca: nil, verify: nil, server_name: nil)
        if cert || key || ca || verify == false
          verify = !ca.nil? if verify.nil?
          cert_pem = cert ? TLS.coerce_pem(cert) : nil
          key_pem  = key  ? TLS.coerce_pem(key)  : nil
          ca_pem   = ca   ? TLS.coerce_pem(ca)   : nil
          server_name ||= TLS.extract_host(url)
          _dial_tls(url, cert_pem, key_pem, ca_pem, verify, server_name)
        else
          _dial(url)
        end
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
