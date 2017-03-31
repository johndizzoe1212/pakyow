require "pakyow/version"
require "pakyow/logger/colorizer"

require "listen"

module Pakyow
  # @api private
  module Commands
    # @api private
    class Server
      def initialize(env: nil, port: nil, host: nil, server: nil)
        @env    = env.to_s
        @port   =   port || Pakyow.config.server.port
        @host   =   host || Pakyow.config.server.host
        @server = server || Pakyow.config.server.default
      end

      def run
        puts Logger::Colorizer.colorize(
          File.read(
            File.expand_path("../output/splash.txt", __FILE__)
          ).gsub!("{v}", "v#{VERSION}"), :error
        )

        puts "Running with #{@server} at http://#{@host}:#{@port}"

        preload
        start_process
        trap_interrupts
        watch_for_changes
      end

      protected

      def preload
        require "bundler/setup"
      end

      def start_process
        if Process.respond_to?(:fork)
          @pid = Process.fork do
            start_server
          end
        else
          start_server
        end
      end

      def stop_process
        Process.kill("INT", @pid) if @pid
      end

      def restart_process
        stop_process; start_process
      end

      def start_server
        require "./config/environment"
        Pakyow.setup(env: @env).run(port: @port, host: @host, server: @server, Silent: true)
      end

      def trap_interrupts
        Pakyow::STOP_SIGNALS.each do |signal|
          trap(signal) {
            stop_process; exit
          }
        end
      end

      def watch_for_changes
        listener = Listen.to(".") do |modified, added, removed|
          restart_process
        end

        listener.start
        sleep
      end
    end
  end
end
