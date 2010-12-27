How it works
============

Basically, two daemons are running: `receivr.rb` and `sendr.rb`:

* [Receivr][https://github.com/Pluies/remaildr/blob/master/bin/receivr_daemon.rb] checks the POP3 mailbox and, processes the incoming emails, put remaildrs into the database if needed, then sleeps and loops.
* [Sendr][https://github.com/Pluies/remaildr/blob/master/bin/sendr_daemon.rb] checks if any email needs to be sent, send it if applicable, sleeps and loops.

The database is a very simple SQLite base at the time, composed of only one table itself containing three columns by email: id, timestamp, and a BLOB containing the marshalled Ruby Mail object to send.

More info at my [blogpost][http://www.uponmyshoulder.com/blog/2010/remaildr-the-tech-bits/].

Logging
=======

The daemons are logging inside their own logs folder. These logs are rotated by [Daemons][daemons.rubyforge.org].


Monitoring
==========

Basic monitoring is offered by the q&d [status.sh][https://github.com/Pluies/remaildr/blob/master/bin/status.sh] script.


Will it crash?
==============

It might. But Daemons has a built-in monitoring, so if any of the script indeed crashes, it will be kicked alive again. Yeah!

The problem is if `receivr.rb` crashes on a particularly badly-handled message, it might fail at reboot and keep failing. Deleting problematic message in the POP inbox is TODO at the moment.


