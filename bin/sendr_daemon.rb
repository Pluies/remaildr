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
		result = db.execute("select id, send_at, msg from remaildrs where send_at < ?", DateTime.now.strftime('%Y-%m-%d %H:%M:%S') )

		log.debug "#{result.count.to_s} remaildrs to process"

		start_time = Time.now
		result.each do |row|
			remaildr = Marshal.load( Base64.decode64(row[2]) )
			remaildr.deliver!
			db.execute("delete from remaildrs where id=?", row[0])
		end
		log.info "#{result.count.to_s} remaildrs processed in #{Time.now - start_time} seconds" if result.count > 0
		sleep 1
	end
end

