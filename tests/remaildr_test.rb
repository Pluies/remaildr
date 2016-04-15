require "../bin/remaildr"
require "mail"
require "test/unit"

Mail.defaults do
  delivery_method :test
end

class TestRemaildr < Test::Unit::TestCase
  def setup
    mails = []
    tos = ['10mn@remaildr.com', 'wrongaddress@remaildr.com', '500days@remaildr.com',
	   '20minutes@remaildr.com', '30m@remaildr.com', '1h@remaildr.com',
	   '1d@remaildr.com', '25h@remaildr.com', '3days@remaildr.com',
	   '1week@remaildr.com', '10jours@remaildr.com', '5wks@remaildr.com',
	   '3months@remaildr.com', '300dias@remaildr.com']
    tos.each do |to_address|
      mail = Mail.new do
	from    'someone@example.com'
	to      to_address.to_s
	subject 'This is a test email'
	body    'This is a test email'
	date    DateTime.now
      end
      mail['X-original-to'] = to_address
      mails << mail
    end
    @remaildrs         = mails[0 .. 2].map{|m| Remaildr.new m, 365 }
    @correct_remaildrs = mails[3..999].map{|m| Remaildr.new m, 365 }
  end

  def test_valid_remaildr
    assert @remaildrs[0].valid_remaildr?
    # Send back to the right address
    assert_equal @remaildrs[0].remaildr.to, @remaildrs[0].orig_mail.from
    # Time to send back
    assert @remaildrs[0].send_at > DateTime.now
    in15mn = DateTime.now + 15.0/24/60
    assert @remaildrs[0].send_at < in15mn
    # Actually sending back
    assert @remaildrs[0].send!
  end

  def test_times
    (1 ... @correct_remaildrs.length).each do |i|
      (m1, m2) = @correct_remaildrs[i-1], @correct_remaildrs[i]
      assert m1.send_at < m2.send_at,
	"Mail ##{i-1} to #{m1.orig_mail.to} is set to be sent before mail ##{i} to #{m2.orig_mail.to}"
    end
  end

  def test_invalid_remaildr
    assert_equal false, @remaildrs[1].valid_remaildr?
    assert_nothing_raised{ @remaildrs[1].prepare_forward }
    assert_equal "florent", @remaildrs[1].remaildr.to.first
  end

  def test_remaildr_too_far_in_the_future
    assert_equal false, @remaildrs[2].valid_remaildr?
    assert_nothing_raised{ @remaildrs[2].prepare_forward }
    assert_equal "florent", @remaildrs[2].remaildr.to.first
  end

  def test_invalid_domain
    mail = Mail.new do
      from    'someone@example.com'
      to      'wrongdomain@example.com'
      subject 'This is a test email'
      body    'This is a test email'
      date    DateTime.now
    end
    mail['X-original-to'] = 'wrongdomain@example.com'
    assert_raise RuntimeError do
      Remaildr.new(mail, 365)
    end
  end
end
