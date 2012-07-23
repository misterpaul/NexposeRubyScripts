=begin
	
Script: ApplyExceptionToGroup
Author: mister paul
Date: 2012-07-20

This script assists you with applying vulnerability exceptions to a dynamic asset group.
In my mind, this is Nexpose's biggest current shortcoming.  Hopefully, Rapid7 will 
implement this functionality in Nexpose soon, and this script will become obsolete!

Say you have 100 red hat servers that report a dozen OpenSSH false positives
(Red Hat users know this situation well), you only need to:
* create an exception on a single server for each false positive vulnerability
* create a dynamic asset group that identifies all the impacted servers
* run this script to apply the exception to all the assets in that group

Over time, membership in that dynamic asset group may grow.  This script checks
for duplicates, so you can use this script again, and it will only create exceptions
for assets that didn't already have this specific exception.

When you run the script, it asks for the usual stuff (Nexpose server, port, user id, 
password).  Then, it ask for the filename to use to create a list of current exceptions.
You will need this list to determine the exception number(s) to apply to the dynamic asset
group.  But, if you run this script multiple times, you only need it once.  You
can enter "none" for the file name and it will skip the file creation.  

I recommend opening the vulnerability list in a spreadsheet, and filtering as needed
to stay organized. (I typically filter by the submitter, status, and maybe Vuln ID.)

The script will then ask you for the ids of the exceptions to replicate.  You can apply
multiple exceptions to your group at once by separating the exceptions ids with spaces. 
At this point, you need to dig through your spreadsheet and find the id's of the  exceptions 
you want to apply to this group.  NOTE: Don't use the numbers from the Nexpose GUI!  Nexpose
builds a table on the fly with its own unique ids; they are not the exception id. I have 
been unable to find the exception id within the GUI.  If it is there, give me feedback and 
I'll update this.

Next, the script asks for a string to filter your group list.  You don't need to filter for
anything, but if you have a ton of dynamic asset groups (as I do), this may help. I 
organize my dynamic asset groups with standard prefixes.  I use "Exception Assets:" 
as a prefix for any dynamic groups I create for this script.  For example, I might 
have the group "Exception Assets: Red Hat Servers" for the Red Hat servers that I want 
to apply the OpenSSH exceptions to.  You'll probably want to edit the code so the default
is appropriate for you.

After that, the script will list all your groups (that match your filter), and let you pick 
the group to apply these exceptions to. Enter the number listed (and you can only do one
group at a time).  NOTE: these are not the Nexpose group ids.

Finally, the script starts creating exceptions for all the assets in your group.  It replicates
the exception exactly, EXCEPT:
* the requester is you
* it inserts text at the beginning of the comment that indicates that this exception was
  created by the script, who the original requester was, what the exception id is that
  was used as a template, and what dynamic group was used.

If the folks requesting exceptions are doing a good job documenting the exception in the 
comments, we might truncate the comment.  Hopefully the info at the top of the comment
will help you track down the original.

This script is a sample. You may need to modify it for your own environment. Use
at your own risk.  It may contain bugs.
	
=end


require 'rubygems'
require 'nexpose'
require 'highline/import'  
require 'csv'

thedate = DateTime.now
# Defaults: Change to suit your environment.
default_host = 'your-host'
default_port = 3780
default_name = 'your-nexpose-id'
default_file = 'ExceptionList_' + thedate.strftime('%Y-%m-%d--%H%M') + '.csv'
default_logfile = 'ApplyExceptionToGroup_' + thedate.strftime('%Y-%m-%d--%H%M') + '.log'
default_filter = 'Exception Assets'
 
puts # blank line for clarity
host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
port = ask('Enter the port for Nexpose: ') { |q| q.default = default_port.to_s }
user = ask('Enter your username:  ') { |q| q.default = default_name }
pass = ask('Enter your password:  ') { |q| q.echo = '*' }
puts
file = ask('Enter the filename for a list of current vulnerability exceptions. Enter "none" (without quotes) if you don\'t want to create the file: ') { |q| q.default = default_file }
puts
logfile = ask('Enter the filename to log results into: ') { |q| q.default = default_logfile }

begin

	# Create a connection to the NeXpose instance
	@nsc = Nexpose::Connection.new(host, user, pass, port)
	# Authenticate to this instance (throws an exception if this fails)
	@nsc.login	

	# get all vulnerability exceptions and load them in a file for the user to select one to replicate
	exceptions = @nsc.vuln_listing
	unless file == 'none'
		begin
			CSV.open(file, 'wb') do |csv|

				csv << ['Vuln ID', 'Exception ID', 'Submitter', 'Reviewer', 'Status', 'Reason', 'Scope', 'Device id', 'port', 'expiration', 'vuln key', 'submitter comment', 'reviewer comment']
				exceptions.each do |e|
					csv << e.values
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
	replicateIds = ask ('Enter the id(s) for exception to replicate for the group (separate ids by spaces): ')
	idList = replicateIds.split(' ')

	# select which group we're creating exceptions for
	puts
	filter = ask ('Enter a string to use to filter the group list. Enter "none" (without quotes) for no filter: ') { |q| q.default = default_filter }
	grouplist = @nsc.asset_groups_listing.sort_by {|g| g[:name]}.select { |h| filter != 'none' ? h[:name] =~ /#{filter}/ : true }
	choicemap = Hash.new
	choice = choose do |menu|
		menu.prompt = 'Please select the group to use:'
		grouplist.each do |grp|
			menu.choice(grp[:name])
			choicemap[grp[:name]] = grp[:asset_group_id]
		end
	end
	asset_group = @nsc.asset_group_config(choicemap[choice])

	# get the details from the appropriate exception
	exceptions = @nsc.vuln_listing
	idList.each do |replicateId|			
		replicate = Array.new      # array used to hold data to copy
		exceptionList = Array.new  # array used to validate that an exception is only applied once

		exceptions.each do |e|
			if e[:exception_id] == replicateId
				replicate = e
			end
			exceptionList << { :device_id => e[:device_id].nil? ? '' : e[:device_id], 
							   :vuln_id   => e[:vuln_id], 
							   :scope     => e[:scope], 
							   :port_no   => e[:port_no].nil? ? '' : e[:port_no], 
							   :vuln_key  => e[:vuln_key].nil? ? '' : e[:vuln_key],  
							   :status    => e[:status]  }
		end

		# begin logging
		File.open(logfile, 'w') do |log|
			log.puts 'Log for ApplyExceptionToGroup, ' + thedate.strftime('%Y-%m-%d--%H%M')
			log.puts
			log.puts 'Exception to replicate:'
			log.puts 'exception_id: ' + replicateId         + ', ' +
			         'vuln_id: '   + replicate[:vuln_id]    + ', ' +
				     'device_id: ' + replicate[:device_id]  + ', ' +
				     'submitter: ' + replicate[:submitter]  + ', ' +
				     'reason: '    + replicate[:reason]     + ', ' +
				     'scope: '     + replicate[:scope]      + ', ' +
				     'comment: '   + (replicate[:submitter_comment].nil?  ? '' : replicate[:submitter_comment].to_s) + ', ' +
				     'port_no: '   + (replicate[:port_no].nil?            ? '' : replicate[:port_no].to_s)           + ', ' +
				     'vuln_key: '  + (replicate[:vuln_key].nil?           ? '' : replicate[:vuln_key].to_s) 

			# add some info to the comment to document this script's actions
			comment = 'This exception auto-created using ApplyExceptionToGroup ruby script, based on Exception #' + 
					   replicateId + ' requested by ' + replicate[:submitter] + 
					   ', applied to group \'' + choice + "'.\r\n" + replicate[:submitter_comment] 
					   # NOTE: use of double quotes required above for \r\n to work
			# comments cannot be more than 1024 characters
			if comment.length > 1024
				comment = comment.slice(0..1011) + ' [truncated]'	
			end

			# now go create the new exceptions for each asset
			asset_group.each do |asset|
				log.puts # toss an extra line in for clarity

				# check for duplicates
				# a duplicate is an existing exception with the same device id, vulnerability id, scope, port, and vuln key
				# AND is not deleted
				dupe = exceptionList.select { |e| 
					  ( (asset[:device_id].nil? ? '' : asset[:device_id].to_s)       == e[:device_id].to_s) && 
					  ( replicate[:vuln_id].to_s                                     == e[:vuln_id].to_s  ) &&
					  ( replicate[:scope].to_s                                       == e[:scope].to_s    ) &&
					  ( (replicate[:port_no].nil? ? '' : replicate[:port_no].to_s)   == e[:port_no].to_s  ) &&
					  ( (replicate[:vuln_key].nil? ? '' : replicate[:vuln_key].to_s) == e[:vuln_key].to_s ) &&
					    e[:status] != 'Deleted'   }
				if dupe.size >  0
					log.puts 'Duplicate: did not create new exception for device ' + asset[:device_id].to_s
					next
				end
				
				# not a duplicate. so build the exception
				exceptionDetails = Hash.new
				exceptionDetails[:vuln_id] = replicate[:vuln_id]
				exceptionDetails[:reason] = replicate[:reason]
				exceptionDetails[:scope] = replicate[:scope]
				exceptionDetails[:comment] = comment
				exceptionDetails[:device_id] = asset[:device_id]
				unless replicate[:scope] =~ /All Instances on a Specific Asset/ 
					exceptionDetails[:port] = replicate[:port_no]
					exceptionDetails[:vuln_key] = replicate[:vuln_key]
				end

				exception = @nsc.vuln_exception_create(exceptionDetails)
				log.puts 'Created Exception:'
				log.puts 'exception_id: ' + exception.to_s                    + ', ' +
				         'vuln_id: '      + exceptionDetails[:vuln_id]        + ', ' +
				         'device_id: '    + exceptionDetails[:device_id].to_s + ', ' +
				         'reason: '       + exceptionDetails[:reason]         + ', ' +
    				     'scope: '        + exceptionDetails[:scope]          + ', ' +
	    			     'comment: '      + (exceptionDetails[:comment].nil?  ? '' : exceptionDetails[:comment].to_s) + ', ' +
		    		     'port_no: '      + (exceptionDetails[:port_no].nil?  ? '' : exceptionDetails[:port_no].to_s) + ', ' +
			    	     'vuln_key: '     + (exceptionDetails[:vuln_key].nil? ? '' : exceptionDetails[:vuln_key].to_s) 
			end
		end
	end

rescue ::Nexpose::APIError => e
	$stderr.puts ('Nexpose API failure: #{e.reason}')
	exit(1)

	# should also rescue file errors
end

