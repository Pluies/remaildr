require 'rubygems'
require 'date'
require 'mail'

# Parameters to retrieve mails
Mail.defaults do
  retriever_method :pop3, {
    :address             => "localhost",
    :port                => 110,
    :user_name           => 'remind',
    :password            => 'r3mind',
    :enable_ssl          => false,
  }
  delivery_method :sendmail
end

puts "-- Emptying POP3 mailbox... --"

Mail.delete_all


