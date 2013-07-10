#!/usr/bin/ruby

require 'rubygems'
require 'base64'
require 'daemons'
require 'date'
require 'logger'
require 'mail'
require './remaildr'
require 'pg'
require 'parseconfig'

base = File.dirname(File.expand_path(__FILE__)).gsub(/bin$/, "") # i.e. the folder just above us

daemon_options = {
	:dir_mode  => :normal,    # Keeps the pid file
	:dir       => base+"run", # in ../run
	:monitor   => true,       # Restart the daemon if it dies
	:multiple  => false,      # Only one instance at a time
	:backtrace => true        # If an unhandled exception crashes the daemon, log it
}

Daemons.run_proc('sendr.rb', daemon_options) do

	config = ParseConfig.new(base + 'remaildr.config')
	log = Logger.new base+'logs/sendr.log', 10, 2048000
	log.level = Logger::INFO
	log.info "Launching sendr daemon..."

	# Send any email that need sending
	loop do
		attempts = 0

		begin
			db = PGconn.open(:dbname   => config['db']['db_name'],
						  :user     => config['db']['user'],
						  :password => config['db']['password'])

			result = db.exec("SELECT id, send_at, msg FROM remaildrs WHERE send_at < current_timestamp at time zone 'utc'")
		rescue
			attempts += 1
			retry unless attempts > 3
			log.error "Can't get mail from DB - sleeping for #{config['db']['minutesToSleepWhenIssue']} minute(s)"
			sleep config['db']['minutesToSleepWhenIssue'].to_i * 60
			next
		ensure
			db.close unless db.nil?
		end


		log.debug "#{result.count.to_s} remaildrs to process"

		all_start_time = Time.now
		result.each do |row|
			start_time = Time.now
			remaildr = Marshal.load( Base64.decode64(row['msg']) )
			marshalled_time = Time.now
			remaildr.deliver!
			delivered_time = Time.now

			# Safe removal
			begin
				db = PGconn.open(:dbname   => config['db']['db_name'],
							  :user     => config['db']['user'],
							  :password => config['db']['password'])
				db.exec("DELETE FROM remaildrs WHERE id=$1", [row['id']])
			rescue
				attempts += 1
				retry unless attempts > 3
				log.error "Can't delete mail from DB - pretty bad."
				next
			ensure
				db.close unless db.nil?
			end

			log.info "Marshall: #{marshalled_time - start_time}s, deliver: #{delivered_time - marshalled_time}, delete: #{Time.now - delivered_time}s"
		end
		log.info "#{result.count.to_s} remaildrs processed in #{Time.now - all_start_time} seconds" if result.count > 0
		sleep 5
	end
end

