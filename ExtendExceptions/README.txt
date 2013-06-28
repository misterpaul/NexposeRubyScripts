Script: ExtendExceptions
Author: mister paul
Date: 2013-06-28

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! IMPORTANT: There is a bug in the Ruby Nexpose Gem.  Until it is fixed,   !!
!!            you need to manually change line 461 of the file              !!
!!            nexpose-0.2.6\lib\nexpose\vuln.rb                             !!
!!                                                                          !!
!!            In version 0.2.6 of the gem, line 461 currently is:           !!
!!   if expiration_date && !expiration_date.empty? && expiration_date =~ /\A\desc{4}-(\desc{2})-(\desc{2})\z/
!!                                                                          !!
!!            You need to change it to:                                     !!
!!   if expiration_date && !expiration_date.empty? && expiration_date =~ /\A\d{4}-(\d{2})-(\d{2})\z/
!!                                                                          !!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


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