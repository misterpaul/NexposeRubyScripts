#!/usr/bin/env ruby

# This forces the version, incase they update it again
# and make stuff not backward-compatible.
gem 'nexpose', '=5.1.0'

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

#gem 'nexpose'
require 'rubygems'
require 'nexpose'
require 'time'
require 'highline/import'
require 'colorize'
include Nexpose

defaultHost = "your-host"
defaultPort = "3780"
defaultName = "your-nexpose-id"
defaultFile = "/tmp/NetworkCoverageReport_" + DateTime.now.strftime('%Y-%m-%d--%H%M') + ".csv"

host = ask("Enter the server name (host) for NeXpose: ") { |q| q.default = defaultHost }
port = ask ("Enter the port for NeXpose: ") { |q| q.default = defaultPort }
user = ask("Enter your username: ") { |q| q.default = defaultName }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
file = ask ("Enter the filename to save the results into: ") { |q| q.default = defaultFile }





#
# Connect and authenticate
#
begin
  @nsc = Connection.new(host, user, pass, port)
  @nsc.login
  at_exit { @nsc.logout }
 

	# sitehash is a hash of sites, where the key is the site id
	# and the value is the site object
	# the purpose is to be able to get a site object from its id
	sites = Hash.new

	# ips is a hash, where the key is the starting IP of a range,
	# and the value is a list of hashes, where each hash is an IPRange object (key) and
	# a site id (value)
	# --start_ip-- ----- range to site map ------
	# ip range site id
	#{ 10.1.20.21 =>[ {10.1.20.21 - 10.1.20.22 =>1} ],
	# 10.20.171.8 =>[ {10.20.171.8 =>1} ],
	# 10.20.171.10=>[ {10.20.171.10 =>1} ],
	# 10.20.172.10=>[ {10.20.172.10 =>1} ],
	# 10.20.174.5 =>[ {10.20.174.5 - 10.20.174.6=>1} ],
	# 10.20.176.2 =>[ {10.20.176.2 =>1} ]
	#}
	ips = Hash.new

	sitelist = @nsc.sites

	sitelist.each do |s|
		site = Site.load(@nsc, s.id)
		sites[s.id] = s.name # site_id=>site name
		puts ("site: ##{s.id.to_s.magenta}\tname: #{s.name.to_s.yellow.bold}")

		#require 'debug'
		site.included_addresses.each do |h|
			puts h.class.to_s.green.bold
			if h.is_a?(IPRange) 
				puts h.from.class
				if h.to.nil?
					range = h.from.to_s
				else
					puts h.to.class
					range = h.from.to_s + " - " + h.to.to_s
				end

#				range = h.from + (h.to.nil? ? "" : " - " + h.to)
				if ips[h.from.to_s].nil?
					ips[h.from.to_s] = [{range => s.id}]
				else
					ips[h.from.to_s].push( {range => s.id} )
				end
			end
		end
	end	

	File.open(file, 'w') do |f| # yeah, i should use CSV. Didn't know about it when I wrote this.
		f.puts ("IP Range,Site")
		#require 'debug'

		ips.keys.sort.each do |start_ip|
			ips[start_ip].each do |range2site_map|
				range2site_map.keys.each do |r|
					#puts r.to_s + ": " + sites[range2site_map[r]]
					f.puts r.to_s + "," + sites[range2site_map[r]]
				end
			end
		end
	end

rescue ::Nexpose::APIError => e
  $stderr.puts "Failure: #{e.reason}"
  exit(1)
end
