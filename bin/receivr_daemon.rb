#!/usr/bin/env ruby

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

Daemons.run_proc('receivr.rb', daemon_options) do

  config = ParseConfig.new(base + 'remaildr.config')

  # Parameters to retrieve mails
  Mail.defaults do
    retriever_method :pop3, {
      :address             => config['mail']['address'],
      :port                => config['mail']['port'].to_i,
      :user_name           => config['mail']['user_name'],
      :password            => config['mail']['password'],
      :enable_ssl          => false,
    }
    delivery_method :sendmail
  end

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
    catch :db_error do
      inbox.each do |received_mail|

        begin
          new_mail = Remaildr.new received_mail, config['remaildr']['max_time_in_days'].to_i
        rescue Encoding::UndefinedConversionError => e
          log.error 'Encoding issue, skipping message.'
          log.error e.to_s
          next
        end

        log.debug new_mail.remaildr.to_s
        log.info "SENT_TO " + new_mail.remaildr_address

        if Remaildr.blacklisted? new_mail.remaildr_address, config['remaildr']['blacklist']
          # BOOM! Blacklisted.
          log.info "Email sent to blacklisted address #{new_mail.remaildr_address}, dropping"
          next
        end

        if new_mail.valid_remaildr?
          # We need to format the string prettily for Postgres
          send_at_str = new_mail.send_at.to_time.utc.strftime('%Y-%m-%d %H:%M:%S')
          log.debug send_at_str

          attempts = 0
          begin
            db = PGconn.open(:dbname   => config['db']['db_name'],
                             :user     => config['db']['user'],
                             :password => config['db']['password'])
            db.exec("INSERT INTO remaildrs(send_at, msg) VALUES($1, $2)",
                    [send_at_str, Base64.encode64(Marshal.dump(new_mail.remaildr))])
          rescue => error
            attempts += 1
            retry unless attempts > 3
            log.error "Can't put mail into DB - sleeping for #{config['db']['minutesToSleepWhenIssue']} minute(s)"
            log.error error.to_s
            sleep config['db']['minutesToSleepWhenIssue'].to_i * 60
            throw :db_error
          ensure
            db.close unless db.nil?
          end
        else
          new_mail.forward!
        end
      end
      Mail.delete_all
    end

    sleep 10
  end
end

