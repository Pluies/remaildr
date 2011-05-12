require 'rubygems'
require 'date'
require 'mail'

# Basically just a wrapper for the email to send,
# plus some helper methods to build it up.
class Remaildr
	attr_accessor :orig_mail, :remaildr, :send_at
	def initialize(orig_mail)
		@orig_mail = orig_mail
		@remaildr = @orig_mail.dup
		# Now we duplicated the incoming mail, let's add our data		
		@remaildr.received = nil
		@remaildr.message_id = nil
		@remaildr.delivery_method :sendmail
		@remaildr.to = @orig_mail.from.first
		@remaildr.from = "Remaildr <remind@remaildr.com>"
		@remaildr.subject = if @orig_mail.subject != nil # Beware of the nil access. Mail makes subject "nil" when empty
					    "Remaildr: " + @orig_mail.subject
				    else
					    "Remaildr"
				    end
		# Detects if the remaildr is valid and computes when to send it, based
		# on the address it was sent to and when it arrived
		compute_delay
	end

	def send!
		@remaildr.deliver!
	end

	# Forward the messages who don't conform to time@remaildr
	def forward!
		@remaildr.subject = "#{@remaildr.subject} (from #{@orig_mail.from.first} to #{remaildr_address})"
		@remaildr.to = "florent"
		@remaildr.deliver!
	end

	def remaildr?
		 return @remaildr_detected
	end

	def compute_delay
		sent_to = remaildr_address
		received_at = @orig_mail.date
		delay = 0.0
		if sent_to =~ /test/
			@remaildr_detected = true
		end
		if sent_to =~ /(\d+)(mn?|mi?n|minute|minuta)s?/
			@remaildr_detected = true
			delay += ($1.to_i)/24.0/60.0
		end
		if sent_to =~ /(\d+)(hr?|hour|heure|hora|stunde)s?/
			@remaildr_detected = true
			delay += ($1.to_i)/24.0
		end
		if sent_to =~ /(\d+)(d|day|j|jour|dia|tag)s?/
			@remaildr_detected = true
			delay += $1.to_i
		end
		# only accept if the delay is between now and 30 days
		if (0..30) === delay
			@send_at = received_at + delay
		end
	end

	# Find the actual @remaildr.com address the mail was sent to
	def remaildr_address
		# X-Original-To is set by Postfix because of the catch-all. Should work all the time.
		if @orig_mail.header["x-original-to"]
			return @orig_mail.header["x-original-to"].value if @orig_mail.header["x-original-to"].value =~ /@remaildr\.com$/
		end
		# But just in case... Look into the To:
		@orig_mail.to.each do |address|
			return address if address =~ /@remaildr\.com$/
		end
		# If not found in the To, look into CC
		if @orig_mail.cc
			@orig_mail.cc.each do |address|
				return address if address =~ /@remaildr\.com$/
			end
		end
		# At this point, if no address is found in X-Orig, To or CC, I have no idea how this email got here
		error_message = "No @remaildr.com address found in To: #{@orig_mail.to}"
		error_message += ", CC: #{@orig_mail.cc}" if @orig_mail.cc
		error_message += ", BCC: #{@orig_mail.bcc}" if @orig_mail.bcc
		raise error_message
	end
end

