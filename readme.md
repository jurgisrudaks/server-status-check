Server status check script
===================

Simple Script which check status of listed servers and if any of the servers listed are down, and rules are met - notify via email.

----------


Installation
-------------
><b>Note:</b> following steps provided assumes that you are using Ubuntu/Debian based OS

For SMTP email sending to work please run these commands:
>sudo apt-get update && sudo apt-get install sendemail libio-socket-ssl-perl libnet-ssleay-perl perl

For Mailgun email sending to work please ensure you have curl installed
>sudo apt-get update && sudo apt-get install php5-curl

Configuration
-------------

###Configuration file
Configuration file is located in the extracted directory and is called <b>config.conf</b>. Configuration file is used to configure email method used for email notifications, notification frequency , etc...

####General configuration

>\# Method to use for email sending - smtp / mailgun
>EMAIL_METHOD=mailgun
>
> \# General email config
>EMAIL_FROM=statuscheck@samples.mailgun.org
>EMAIL_TO=jurgis@rudaks.lv

<b>EMAIL_METHOD</b> can be <b>smtp</b> or <b>mailgun</b>
<b>EMAIL_FROM</b> defines from what email address email should be sent
<b>EMAIL_TO</b> to which email address email should be sent

###Configure method used for email sending

####Mailgun
> <b>Note:</b> To use <b>Mailgun</b> for email sending make sure you have installed all prerequisites mentioned under <b>Installation</b> and that you have registered account with [Mailgun email service](https://www.mailgun.com/ "Mailgun") - it's email service mostly used by developers to test and develop applications.

In <b>config.conf</b> you will find following config keys:

>\# Mailgun email config
>EMAIL_MAILGUN_API_KEY=3ax6xnjp29jd6fds4gc373sgvjxteol0
>EMAIL_MAILGUN_DOMAIN=samples.mailgun.org

<b>EMAIL_MAILGUN_API_KEY</b> As key name already states this is the Mailgun API key which can be obtained from your Mailgun dashboard please refer to [Mailgun quickstart guide](https://documentation.mailgun.com/quickstart-sending.html#send-via-api "Mailgun quickstart") for more inforamtion.
<b>EMAIL_MAILGUN_DOMAIN</b> Same as API key you can get this value from your Mailgun Dashboard refer to [Mailgun quickstart guide](https://documentation.mailgun.com/quickstart-sending.html#send-via-api "Mailgun quickstart") for more information

####SMTP
> <b>Note:</b> To use SMTP for email sending make sure you have installed all prerequisites mentioned under <b>Installation</b>

In <b>config.conf</b> following configuration keys can be found for SMTP email sending.

>\# SMTP email config
>\# Example Google SMTP
>EMAIL_SMTP_SERVER=smtp.gmail.com:587
>EMAIL_TLS=yes
>EMAIL_USERNAME=gmailemail
>EMAIL_PASSWORD=gmailpassword

<b>EMAIL_SMTP_SERVER</b> SMTP server address and port separated by <b>:</b>
<b>EMAIL_TLS</b> should TLS be used to encrypt connection or not - possible values <b>yes</b> / <b>no</b>
<b>EMAIL_USERNAME</b> SMTP server username
<b>EMAIL_PASSWORD</b> SMTP server password

###Notifications frequency configuration
>\# After which fail we should send email
>\# specify when email notification should be sent out:
>\# every_nth_time - email will be sent when server have failed to respond every (nth) time
>\# fail_count_reached - email will be sent when specified fail count will be reached
>NOTIFY_METHOD=fail_count_reached
>
>\# Only used if every_nth_time method have been specified for NOTIFY_METHOD
>\# Specifies on which nth server failure email notification should be sent
>NOTIFY_EVERY_NTH_TIME=3
>
>\# Only used if fail_count_reached method have been specified for NOTIFY_METHOD
>\# Can be an array or an integer
>\# - if integer specified email will be sent out when server have failed
>\# for specified times in a row
>\# - If array then email will be sent out if fail count equals to any value specified in array
>\# For example:
>\# uncomment below line to send out email when server have not responded three times
>NOTIFY_WHEN_FAIL_COUNT=3
>
>\# or uncomment this line if email should be sent out if server have not responded three, nine and 18 times
>\#NOTIFY_WHEN_FAIL_COUNT=(3 9 18)

<b>NOTIFY_METHOD</b> Can be <b>every_nth_time</b> or <b>fail_count_reached</b>. <b>every_nth_time</b> - email notification will be sent out every <i>nth</i> fail. <b>fail_count_reached</b> email notification will be sent when fail count reaches specified number or is equal to one of the numbers in array - if <b>NOTIFY_WHEN_FAIL_COUNT</b> is <i>array</i>
<b>NOTIFY_EVERY_NTH_TIME</b> Used only if <b>NOTIFY_METHOD</b> set to <b>every_nth_time</b> - specifies <i>nth</i> time email should be sent.
<b>NOTIFY_WHEN_FAIL_COUNT</b> Used only if <b>NOTIFY_METHOD</b> set to <b>fail_count_reached</b> - specifies fail count on which email notification should be sent.
><b>Note:</b> more information and examples please see comments in <b>config.conf</b>

###Configure servers to be checked
To configure which servers will be checked cd to extracted/script folder and open file <b>servers.list</b> and add your server ip/hostname in new line - for example:
>test.server
>10.0.0.1
>test.domain.ltd
 
Running
-------------
Extract the archive cd to extracted folder and run
>./statuscheck

Automation
-------------
To use this script to continuously check server status create cron job for it using following command
>crontab -e

Then you might see editor selection choose the editor you would like to use to edit cron job file
when cron job file opens add following line to run script every three minutes
>*/3 * * * * /path/to/statuscheck
