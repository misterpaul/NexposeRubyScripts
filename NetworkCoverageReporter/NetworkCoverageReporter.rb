#!/usr/bin/env ruby

=begin

Network Coverage Reporter
This script generates a comma delimited report to show Network coverage
The report shows all the IP ranges covered within your Nexpose sites
And what sites use the IP ranges

Sample Output:

IP Range, Site
10.0.8.1 - 10.0.8.254,Site1
10.0.9.1 - 10.0.8.127,Site1
10.0.10.1 - 10.0.10.254,Site2
10.0.20.20,Site2

March 6, 2012
misterpaul
updated June 10, 2012 to explicitly require nexpose 0.0.98

=end

gem 'nexpose', '=0.0.98'
require 'rubygems'
require 'nexpose'
require 'time'
require 'highline/import'  

defaultHost = "your-host"
defaultPort = "3780"  
defaultName = "your-nexpose-id"
defaultFile = "NetworkCoverageReport_" + DateTime.now.strftime('%Y-%m-%d--%H%M') + ".csv"

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

# sitehash is a hash of sites, where the key is the site id
# and the value is the site object
# the purpose is to be able to get a site object from its id
sites = Hash.new

# ips is a hash, where the key is the starting IP of a range, 
# and the value is a list of hashes, where each hash is an IPRange object (key) and
# a site id (value)
#  --start_ip--    ----- range to site map ------           
#                      ip range              site id
#{ 10.1.20.21  =>[ {10.1.20.21 - 10.1.20.22  =>1} ], 
#  10.20.171.8 =>[ {10.20.171.8              =>1} ], 
#  10.20.171.10=>[ {10.20.171.10             =>1} ], 
#  10.20.172.10=>[ {10.20.172.10             =>1} ], 
#  10.20.174.5 =>[ {10.20.174.5 - 10.20.174.6=>1} ], 
#  10.20.176.2 =>[ {10.20.176.2              =>1} ]
#}
ips = Hash.new

sitelist = @nsc.site_listing

sitelist.each do |s|
	site = Nexpose::Site.new(@nsc, s[:site_id].to_s)
	sites[s[:site_id]] = s                               # site_id=>site name
	puts ("site: ##{s[:site_id]}\tname: #{s[:name]}")

	#require 'debug'
	site.site_config.hosts.each do |h|
		range = h.from + (h.to.nil? ? "" : " - " + h.to)
		if ips[h.from].nil?
			ips[h.from] = [{range => s[:site_id]}]
		else
			ips[h.from].push( {range => s[:site_id]} )
		end
	end
end	

File.open(file, 'w') do |f| # yeah, i should use CSV.  Didn't know about it when I wrote this.
	f.puts ("IP Range,Site")

	ips.keys.sort.each do |start_ip|
		ips[start_ip].each do |range2site_map|
			range2site_map.keys.each do |r|
				#puts r.to_s + ": " + sites[range2site_map[r]][:name]
				f.puts r.to_s + "," + sites[range2site_map[r]][:name]
			end
		end
	end
end