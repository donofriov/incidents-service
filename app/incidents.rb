# frozen_string_literal: true
require 'webrick'
require 'yaml'
require 'date'

module Incidents
  CANDIDATE_PATHS = ['incidents.yaml', 'example_incidents.yaml'].freeze
  DEFAULT_HOST = '0.0.0.0'
  DEFAULT_PORT = '3000'

  class App
    def initialize(port: ENV.fetch('PORT', DEFAULT_PORT), host: ENV.fetch('HOST', DEFAULT_HOST))
      @port = parse_port(port)
      @host = host
      @server = create_server
      mount_routes
      trap_signals
    rescue KeyError
      abort 'PORT is missing'
    rescue ArgumentError
      abort 'PORT must be an integer'
    end

    def start
      @server.start
    end

    # Expose for tests / graceful shutdown
    def shutdown
      @server.shutdown
    end

    private

    def parse_port(port)
      Integer(port, 10)
    end

    def create_server
      WEBrick::HTTPServer.new(
        Port: @port,
        BindAddress: @host,
        AccessLog: [],
        Logger: WEBrick::Log.new($stderr, WEBrick::Log::INFO)
      )
    end

    def mount_routes
      @server.mount_proc '/' do |_req, res|
        begin
          text = read_incidents_text
          last = last_incident_date(text)
          raise 'No valid incident dates found' unless last

          days  = (Date.today - last).to_i
          label = days == 1 ? '1 day' : "#{days} days"

          res.status = 200
          res['Content-Type'] = 'text/plain; charset=utf-8'
          res.body = +"status: #{label} since the last incident\n" << text
        rescue StandardError => e
          res.status = 500
          res['Content-Type'] = 'text/plain; charset=utf-8'
          res.body = "error: #{e.message}\n"
        end
      end

      @server.mount_proc '/healthz' do |_req, res|
        res.status = 200
        res['Content-Type'] = 'text/plain; charset=utf-8'
        res.body = "ok\n"
      end

      @server.mount_proc '/readyz' do |_req, res|
        begin
          text = read_incidents_text
          last = last_incident_date(text)
          if last
            res.status = 200
            res['Content-Type'] = 'text/plain; charset=utf-8'
            res.body = "ready\n"
          else
            res.status = 503
            res['Content-Type'] = 'text/plain; charset=utf-8'
            res.body = "not ready: no valid incident dates\n"
          end
        rescue StandardError => e
          res.status = 503
          res['Content-Type'] = 'text/plain; charset=utf-8'
          res.body = "not ready: #{e.message}\n"
        end
      end
    end

    def trap_signals
      %w[INT TERM].each { |sig| trap(sig) { @server.shutdown } }
    end

    def read_incidents_text
      path = CANDIDATE_PATHS.find { |p| File.exist?(p) }
      raise 'No incidents file found (expected incidents.yaml or example_incidents.yaml)' unless path

      File.read(path)
    end

    def to_date(val)
      case val
      when Date   then val
      when String then Date.iso8601(val)
      end
    rescue ArgumentError
      nil
    end

    def last_incident_date(yaml_str)
      data = YAML.safe_load(yaml_str, permitted_classes: [Date], aliases: false)
      incidents = data && data['incidents']

      dates = Array(incidents).filter_map { |e| to_date(e['date']) }
      dates.max
    end
  end
end

Incidents::App.new.start
