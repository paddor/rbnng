# frozen_string_literal: true


module NNG
  module Socket
    module Options
      module ReceiverMethods
        def recv_fd
          get_opt_int 'recv-fd'
        end
      end

      module SenderMethods
        def send_fd
          get_opt_int 'send-fd'
        end
      end
    end

    [
      Pair0,
      Pair1,
      Req0,
      Rep0,
      Pull0,
      Sub0,
      Respondent0,
    ].each do |recv_klass|
      recv_klass.include Options::ReceiverMethods
    end

    [
      Pair0,
      Pair1,
      Req0,
      Rep0,
      Push0,
      Pub0,
      Surveyor0,
    ].each do |send_klass|
      send_klass.include Options::SenderMethods
    end
  end
end
