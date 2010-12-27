require 'rubygems'
require 'date'
require 'mail'

# Basically just a wrapper for the email to send,
# plus some helper methods to build it up.
class Remaildr
	attr_accessor :orig_mail, :remaildr
	def initialize(orig_mail)
		@orig_mail = orig_mail
		@remaildr = Mail.new
		@remaildr.delivery_method :sendmail
		@remaildr.from = "Remaildr <remind@remaildr.com>"
		@remaildr.to = @orig_mail.from.first
		@remaildr.subject = if @orig_mail.subject != nil # Beware of the nil access. Mail makes subject "nil" when empty
					    "Remaildr: " + @orig_mail.subject
				    else
					    "Remaildr"
				    end
		if @orig_mail.has_charset?
			@remaildr.charset = @orig_mail.charset
		end
		if @orig_mail.has_mime_version?
			@remaildr.mime_version = @orig_mail.mime_version
		end
		# Extract the plaintext and the html part of the message.
		# Each other part, such as attachments, will be dropped.
		if @orig_mail.multipart?
			@orig_mail.parts.each do |p|
				@remaildr.text_part = p if p.content_type =~ /plain/
				@remaildr.html_part = p if p.content_type =~ /html/
			end
		else
			@remaildr.body = @orig_mail.body.decoded
			@remaildr.body.charset = @orig_mail.body.charset unless @orig_mail.body.charset == nil
			@remaildr.content_type = @orig_mail.content_type unless @orig_mail.content_type == nil
		end 
	end

	def send!
		@remaildr.deliver!
	end

	def forward!
		@remaildr.subject = "#{@remaildr.subject} (from #{@orig_mail.from.first} to #{remaildr_address})"
		@remaildr.to = "florent"
		@remaildr.deliver!
	end

	# Compute when to send the remaildr, based on the address
	# it was sent to and when it arrived
	def send_at
		sent_to = remaildr_address
		received_at = @orig_mail.date
		delay = if sent_to =~ /test/
				0.0
			elsif sent_to =~ /i?n?(\d+)(mn?|minutes?)/
				($1.to_i)/24.0/60.0
			elsif sent_to =~ /i?n?(\d+)(hours?|hrs?|hs?)(\d+)?/
				if $3 # Catches 1h15@, etc
					($1.to_i)/24.0 + ($3.to_i)/24.0/60.0
				else # Simple nhour@
					($1.to_i)/24.0
				end
			elsif sent_to =~ /i?n?(\d+)(d|days?)/
				$1.to_i
			end
		# only return something if the delay is between now and 7 days
		if (0..7) === delay
			return received_at + delay
		else
			return nil
		end
	end

	# In case the remaildr was sent to other people too
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

