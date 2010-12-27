Remaildr
========


How it works
============

Basically, two daemons are running: *receivr* and *sendr*:
* Receivr checks the POP3 mailbox and, processes the incoming emails, put remaildrs into the database if needed, then sleeps and loops.
* Sendr checks if any email needs to be sent, send it if applicable, sleeps and loops.

The database is a very simple SQLite base at the time, composed of only one table itself containing three columns by email: id, timestamp, and a BLOB containing a marshalled Ruby Mail object to send.

Logging
=======

The daemons are logging inside their own ./logs folder. These logs are rotated by logrotate.

