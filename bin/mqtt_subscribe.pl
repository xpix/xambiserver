#!/usr/bin/perl

use DBI();
use strict;
use warnings;
use FileHandle;

use JSON;
my $json = JSON->new;

my ($host, $port, $apikey) = @ARGV;
$host //= 'localhost';
$port //= 1883;


local $| = 1;
printf "Start MQTT Logging\n";

my $database   = "db/xambimqtt.db";
my $dbtable    = "mqtt";

printf "Connect to sqlite database: $database\n";
my $dbh = DBI->connect("DBI:SQLite:dbname=$database", "", "", {'RaiseError' => 1})
            or die $DBI::errstr;

create_table() if(not -s $database);

my $subclient = "/usr/bin/mosquitto_sub -h $host -p $port -v -t /#";
   $subclient = "/usr/bin/mosquitto_sub -u '' -P $apikey -h $host -p $port -v -t /#"
      if($apikey);

printf "Start mqtt client: $subclient\n";
open(SUB, "$subclient|");
SUB->autoflush(1);

printf "Start logging ...\n";
while (my $line = <SUB>) {
   chomp $line;
	my ($topic, $value) = split(/\s+/, $line);
   if($value =~ /\[/){
      my $data = $json->decode($value);
      $value = $data->{'e'}[0]{'v'};
   }
   printf "%s: %s => %s\n", scalar localtime, $topic, $value;
	$dbh->do("INSERT INTO $dbtable (TOPIC, TIMESTAMP, VALUE) VALUES (?,?,?)", 
	            undef, $topic, time, $value);
}

$dbh->disconnect();

exit;

sub create_table {
   printf "New Database, create table and indexes\n";
   ### create table if not exists
   my $stmt = "
      CREATE TABLE $dbtable (
         ID INTEGER PRIMARY KEY AUTOINCREMENT,
         TOPIC          TEXT    NOT NULL,
         TIMESTAMP      INT     NOT NULL,
         VALUE          REAL
      );
      CREATE INDEX topics ON $dbtable (TOPIC);
   ";

   return $dbh->do($stmt);
}
