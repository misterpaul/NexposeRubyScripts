#!/usr/bin/env ruby
# This script generates a comma delimited report to help with scan planning
# The report shows the following information for every site:
#   Site Name
#   Last Scan Start
#   Last Scan Status
#   Last Scan Live Nodes
#   Last Scan Duration
#   Scan Template
#   Scan Engine
#   Next Scan Start  (Not implemented yet)
#   Schedule         (Not implemented yet)

# March 6, 2012
# misterpaul

# you probably want to change the defaults below

require 'rubygems'
require 'nexpose'
require 'time'
require 'highline/import'  

defaultHost = "your-host"
defaultPort = "3780"  
defaultName = "your-nexpose-id"
defaultFile = "ScanPlan_" + DateTime.now.strftime('%Y-%m-%d--%H%M') + ".csv"

host = ask("Enter the server name (host) for NeXpose: ") { |q| q.default = defaultHost }
port = ask ("Enter the port for NeXpose: ") { |q| q.default = defaultPort } 
user = ask("Enter your username:  ") { |q| q.default = defaultName } 
pass = ask("Enter your password:  ") { |q| q.echo = "*" }
file = ask ("Enter the filename to save the results into: ") { |q| q.default = defaultFile }

#
# Connect and authenticate
#
begin

	# Create a connection to the NeXpose instance
	@nsc = Nexpose::Connection.new(host, user, pass, port)

	# Authenticate to this instance (throws an exception if this fails)
	@nsc.login
	
rescue ::Nexpose::APIError => e
	$stderr.puts ("Connection failed: #{e.reason}")
	exit(1)
end

#
# Query a list of all NeXpose sites
#
sites = @nsc.site_listing || []

#
# Get a list of the scanners and make a hash, indexed by id
engines = Nexpose::EngineListing.new(@nsc)
engineList = Hash.new
engines.engines.each do |e|
	engineList[e.id.to_s] = e.name + " (" + e.status + ")"
end

if sites.length == 0
	puts("There are currently no active sites on this NeXpose instance")
else
	# produce a report on the sites
	File.open(file, 'w') do |f|
		f.puts ("Site Name,Last Scan Start,Last Scan Status,Last Scan Live Nodes,Last Scan Duration,Scan Template,Scan Engine,Next Scan Start,Schedule")
		sites.each do |s|
			site = Nexpose::Site.new(@nsc, s[:site_id].to_s)
			puts ("site: ##{s[:site_id]}\tname: #{s[:name]}")
			config = site.site_config
			template = config.scanConfig.name
			# get the name, description, scanConfig.name
			history = site.site_scan_history
			latest = history.getLatestScanSummary
			if latest.nil?
				# no scans.  Fill in info we need by hand
				startTime = ""
				status = ""
				active = ""
				duration = ""
				engineName = ""
			else
				startTime = Time.parse(latest.startTime)
				status = latest.status
				active = latest.nodes_live
				engineName = engineList[latest.engine_id.to_s]
				if latest.endTime.nil? or latest.endTime.empty? 
					duration = ""
				else
					endTime = Time.parse(latest.endTime)
					duration_sec = Time.parse(latest.endTime) - Time.parse(latest.startTime)
					hours = (duration_sec/3600).to_i
					minutes = (duration_sec/60 - hours * 60).to_i
					seconds = (duration_sec - (minutes * 60 + hours * 3600))
					duration = sprintf("%dh %02dm %02ds", hours, minutes, seconds)
				end
			end
			f.puts("#{config.site_name},#{startTime},#{status},#{active},#{duration},#{template},#{engineName},NEXT SCAN,SCHEDULE")
		end	
	end
end
