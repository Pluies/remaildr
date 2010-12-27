require 'rubygems'
require 'sqlite3'

db = SQLite3::Database.new( "remaildrs.db" )
#db.execute( "drop table if exists remaildrs" )
db.execute( "create table if not exists remaildrs( id integer primary key autoincrement,	send_at datetime, msg blob )" )


