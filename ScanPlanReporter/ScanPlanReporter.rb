#!/usr/bin/env ruby
# This script generates a comma delimited report to help with scan planning
# The report shows the following information for every site:
# Site Name
# Last Scan Start
# Last Scan Status
# Last Scan Live Nodes
# Last Scan Duration
# Scan Template
# Scan Engine
# Next Scan Start (Not implemented yet)
# Schedule (Not implemented yet)
 
# March 6, 2012
# modified June 10, 2013 with changes suggested by mdaines to support Nexpose gem 0.2.5
# tested with nexpose 0.2.6 and Ruby 2.0.0
# misterpaul
 
require 'nexpose'
require 'time'
require 'highline/import'
include Nexpose
 
# Defaults: Change to suit your environment.
default_host = 'your-host'
default_port = 3780
default_name = 'your-nexpose-id'
default_file = 'ScanPlan_' + DateTime.now.strftime('%Y-%m-%d--%H%M') + '.csv'
 
host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
port = ask('Enter the port for Nexpose: ') { |q| q.default = default_port.to_s }
user = ask('Enter your username: ') { |q| q.default = default_name }
pass = ask('Enter your password: ') { |q| q.echo = '*' }
file = ask('Enter the filename to save the results into: ') { |q| q.default = default_file }
 
begin
  @nsc = Connection.new(host, user, pass, port)
  @nsc.login
  at_exit { @nsc.logout }
 
  sites = @nsc.sites
 
  # This ensures engines status is up to date.
  @nsc.console_command('version engines')
  engine_list = {}
  @nsc.engines.each do |engine|
    engine_list[engine.id] = "#{engine.name} (#{engine.status})"
  end
 
  if sites.empty?
    puts 'There are currently no active sites on this Nexpose instance.'
  else
    File.open(file, 'w') do |file|
      file.puts 'Site Name,Last Scan Start,Last Scan Status,Last Scan Live Nodes,Last Scan Duration,Scan Template,Scan Engine,Next Scan Start,Schedule'
      sites.each do |s|
        site = Site.load(@nsc, s.id)
        puts "site: ##{site.id}\tname: #{site.name}"
        template = site.scan_template
        latest = @nsc.last_scan(site.id)
        if latest
          start_time = latest.start_time
          status = latest.status
          active = latest.nodes.live
          engine_name = engine_list[site.engine]
          if sched = site.schedules.first
            schedule = "#{sched.type}:#{sched.interval}"
          end
          if latest.end_time
            duration_sec = latest.end_time - start_time
            hours = (duration_sec / 3600).to_i
            minutes = (duration_sec / 60 - hours * 60).to_i
            seconds = (duration_sec - (minutes * 60 + hours * 3600))
            duration = sprintf('%dh %02dm %02ds', hours, minutes, seconds)
          else
            duration = ''
          end
        else
          # No scans found.
          start_time = status = active = duration = engine_name = ''
        end
        file.puts "#{site.name},#{start_time},#{status},#{active},#{duration},#{template},#{engine_name},NEXT SCAN,#{schedule}"
      end
    end
  end
rescue ::Nexpose::APIError => e
  $stderr.puts "Failure: #{e.reason}"
  exit(1)
end
