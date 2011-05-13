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
	:dir_mode => :normal,	# Keeps the pid file...
	:dir => base+"run",	# ...in ../run
	:monitor => true,	# Restart the daemon if it dies
	:multiple => false,	# Only one instance at a time
	:backtrace => true	# Uf an unhandled exception crashes the daemon, log it
}

Daemons.run_proc('sendr.rb', daemon_options) do

	db = SQLite3::Database.new base+"db/remaildrs.db"
	log = Logger.new base+'logs/sendr.log', 10, 2048000
	log.level = Logger::INFO
	log.info "Launching sendr daemon..."

	loop do
		# Send any email that need sending
		retries = 5
		begin
			result = db.execute("select id, send_at, msg from remaildrs where send_at < ?", DateTime.now.strftime('%Y-%m-%d %H:%M:%S') )
		rescue Exception
			sleep 0.01
			if (retries -= 1) > 0
				retry
			else
				log.error "Can't get mail from DB"
			end
		end


		log.debug "#{result.count.to_s} remaildrs to process"

		all_start_time = Time.now
		result.each do |row|
			start_time = Time.now
			remaildr = Marshal.load( Base64.decode64(row[2]) )
			marshalled_time = Time.now
			remaildr.deliver!
			delivered_time = Time.now
			db.execute("delete from remaildrs where id=?", row[0])
			log.info "Marshall: #{marshalled_time - start_time}s, deliver: #{delivered_time - marshalled_time}, delete: #{Time.now - delivered_time}s"
		end
		log.info "#{result.count.to_s} remaildrs processed in #{Time.now - all_start_time} seconds" if result.count > 0
		sleep 5
	end
end

