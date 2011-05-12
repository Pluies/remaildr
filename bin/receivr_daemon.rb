#!/usr/bin/ruby

require 'rubygems'
require 'base64'
require 'daemons'
require 'date'
require 'logger'
require 'mail'
require 'remaildr'
require 'sqlite3'

base = File.dirname(File.expand_path(__FILE__)).gsub(/bin$/, "") # i.e. the folder just above us

daemon_options = {
	:dir_mode => :normal,	# Keeps the pid file
	:dir => base+"run",	# in ../run
	:monitor => true,	# Restart the daemon if it dies
	:multiple => false,	# Only one instance at a time
	:backtrace => true	# If an unhandled exception crashes the daemon, log it
}

Daemons.run_proc('receivr.rb', daemon_options) do

	# Parameters to retrieve mails
	Mail.defaults do
		retriever_method :pop3, {
			:address             => "localhost",
			:port                => 110,
			:user_name           => 'remind',
			:password            => 'fakepass',
			:enable_ssl          => false,
		}
		delivery_method :sendmail
	end

	db = SQLite3::Database.new base+"db/remaildrs.db"
	log = Logger.new base+'logs/receivr.log', 10, 2048000
	log.level = Logger::INFO
	log.info "Launching receivr daemon..."


	loop do
		# Check the inbox. We use the "inbox" variable instead of multiple 
		# Mail.all calls in order to avoid multiple POP requests
		inbox = Mail.all

		if inbox.count > 0
			log.info "#{inbox.count.to_s} emails in inbox"
		end

		# Check POP account for new mails
		inbox.each do |received_mail|
			new_mail = Remaildr.new received_mail
			log.debug new_mail.remaildr.to_s
			log.info "SENT_TO " + new_mail.remaildr_address
			if new_mail.remaildr?
				send_at_str = new_mail.send_at.new_offset(0).strftime('%Y-%m-%d %H:%M:%S')
				log.debug send_at_str
				begin
					db.execute("insert into remaildrs(send_at, msg) values (:send_at, :remaildr)",
						   :send_at => send_at_str,
						   :remaildr => Base64.encode64(Marshal.dump(new_mail.remaildr)) )
				rescue
					log.error "Problem while inserting mail into DB: " + new_mail
				end
			else
				new_mail.forward!
			end
		end
		Mail.delete_all

		sleep 10
	end
end

