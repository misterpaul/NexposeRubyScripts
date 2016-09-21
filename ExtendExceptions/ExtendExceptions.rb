#!/usr/bin/env ruby

=begin
	
Script: ExtendExceptions
Author: mister paul
Date: 2013-06-28

This script assists you with extending the expiration date applied to exceptions.

When you run the script, it asks for the usual stuff (Nexpose server, port, user id, 
password).  Then, it ask for the filename to use to create a list of current exceptions.
You will need this list to determine the exception number(s) to extend.
But, if you run this script multiple times, you only need it once.  You
can enter "none" for the file name and it will skip the file creation.  

I recommend opening the exception list in a spreadsheet, and filtering as needed
to stay organized. 

The script will then ask you for the ids of the exceptions to extend.  You can enter multiple
exception ids, separated by a space.

Next, the script will ask you to enter the new expiration date.  You MUST enter the date
in the YYYY-MM-DD format.

Finally, the script starts extending all the exceptions to the new date.

If you have a lot of exceptions to extend (more than you can paste onto the command line),
you can edit lines 90 & 91 to hard-code your exception numbers and skip the question.

	
=end


gem 'nexpose'
require 'rubygems'
require 'nexpose'
require 'highline/import'  
require 'csv'
include Nexpose

thedate = DateTime.now
# Defaults: Change to suit your environment.
default_host = 'your-host'
default_port = 3780
default_name = 'your-nexpose-id'
default_file = 'ExceptionList_' + thedate.strftime('%Y-%m-%d--%H%M') + '.csv'
default_logfile = 'ExtendExceptions_' + thedate.strftime('%Y-%m-%d--%H%M') + '.log'
default_filter = 'Exception Assets'
 
puts # blank line for clarity
host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
port = ask('Enter the port for Nexpose: ') { |q| q.default = default_port.to_s }
user = ask('Enter your username:  ') { |q| q.default = default_name }
pass = ask('Enter your password:  ') { |q| q.echo = '*' }

begin

	# Create a connection to the NeXpose instance
	nsc = Connection.new(host, user, pass, port)
	nsc.login
	if nsc.session_id
		print "Login Successful\n\n"
	else
		print "Login Failure\n\n"
	end
	at_exit { nsc.logout }
	
	file = ask('Enter the filename for a list of current vulnerability exceptions. Enter "none" (without quotes) if you don\'t want to create the file: ') { |q| q.default = default_file }
	puts
	logfile = ask('Enter the filename to log results into: ') { |q| q.default = default_logfile }

	# get all Approved vulnerability exceptions and load them in a file
	exceptions = nsc.list_vuln_exceptions('Approved')
	unless file == 'none'
		begin
			CSV.open(file, 'wb') do |csv|

				csv << ['Exception ID', 'Vuln ID', 'Submitter', 'Reviewer', 'Status', 'Reason', 'expiration', 'submitter comment', 'reviewer comment']
				exceptions.each do |e|
					csv << [e.id, e.vuln_id, e.submitter, e.reviewer, e.status, e.reason, e.expiration, e.submitter_comment, e.reviewer_comment]
				end
			end
			puts
			puts 'You may now go open ' + file + ' to find the exception id(s) you want.'
		rescue Exception => e
			puts 'Failed to create Exception listing file: ' + file
			puts e
		end
	end


	# now select the excption(s) to replicate
	puts
	replicateIds = ask ('Enter the id(s) for exception(s) to extend (separate ids by spaces): ')
	#replicateIds = "1 2 3"
	idList = replicateIds.split(' ')

	newDate = ask ('Enter the new expiration date for these exceptions (YYYY-MM-DD): ')

	# go and extend!
	# begin logging
	File.open(logfile, 'w') do |log|
		log.puts 'Log for ExtendExceptions, ' + thedate.strftime('%Y-%m-%d--%H%M')

		idList.each do |extendId|			
			log.puts 'Extending exception ' + extendId + ' to newDate'
			extend_vuln = VulnException.new('nil','nil','nil')
			extend_vuln.id = extendId
			if (result = extend_vuln.update_expiration_date(nsc, newDate)) == true
				print extendId + " successfully updated\n"
				STDOUT.flush
			else
				print extendId + " - error updating\n"
				STDOUT.flush
			end
		end
	end

rescue ::Nexpose::APIError => e
	$stderr.puts ('Nexpose API failure: #{e.reason}')
	exit(1)

	# should also rescue file errors
end

