How it works
============

Basically, two daemons are running: `receivr.rb` and `sendr.rb`:

* [Receivr] [1] checks the POP3 mailbox and, processes the incoming emails, put remaildrs into the database if needed, then sleeps and loops.
* [Sendr] [2] checks if any email needs to be sent, send it if applicable, sleeps and loops.

The database is a very simple SQLite base at the time, composed of only one table itself containing three columns by email: id, timestamp, and a BLOB containing the marshalled Ruby Mail object to send.

More info at my [blogpost] [3].


Logging
=======

The daemons are logging inside their own logs folder. These logs are rotated by [Daemons] [4].


Monitoring
==========

Basic monitoring is offered by the q&d [status.sh] [5] script.


Will it crash?
==============

It might. But Daemons has a built-in monitoring, so if any of the script indeed crashes, it will be kicked alive again. Yeah!

The problem is if `receivr.rb` crashes on a particularly badly-handled message, it might fail at reboot and keep failing. Deleting problematic message in the POP inbox is TODO at the moment.


	[1]: [https://github.com/Pluies/remaildr/blob/master/bin/receivr_daemon.rb] "Receivr"
	[2]: [https://github.com/Pluies/remaildr/blob/master/bin/sendr_daemon.rb] "Sendr"
	[3]: [http://www.uponmyshoulder.com/blog/2010/remaildr-the-tech-bits/] "blog post"
	[4]: [daemons.rubyforge.org]
	[5]: [https://github.com/Pluies/remaildr/blob/master/bin/status.sh]
