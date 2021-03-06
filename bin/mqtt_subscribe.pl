#!/usr/bin/perl

use lib './../lib';

use DBI();
use strict;
use warnings;
use FileHandle;

use JSON::XS;
my $json = JSON::XS->new;

my ($host, $port, $apikey) = @ARGV;
$host //= 'localhost';
$port //= 1883;

# messages for: $SYS/broker/messages/*
my $inice = {'received' => 'power', 'sent' => 0, 'stored' => 1};


local $| = 1;
printf "Start MQTT Logging\n";

my $database   = "db/xambimqtt.db";
my $dbtable    = "mqtt";

printf "Connect to sqlite database: $database\n";
my $dbh = DBI->connect("DBI:SQLite:dbname=$database", "", "", {'RaiseError' => 1})
            or die $DBI::errstr;

create_table() if(not -s $database);

my $subclient = "/usr/bin/mosquitto_sub -h $host -p $port -v -t \\\$SYS/broker/messages/# -t /#";
   $subclient = "/usr/bin/mosquitto_sub -u '' -P $apikey -h $host -p $port -v -t \\\$SYS/broker/messages/# -t /#"
      if($apikey);

my $display = $subclient;
$display =~ s/$apikey/TOPSECRET/sig if($apikey);

while(1){
   printf "Start mqtt client: $display\n";
   open(SUB, "$subclient|");
   SUB->autoflush(1);
   
   printf "Start logging ...\n";
   while (my $line = <SUB>) {
      chomp $line;
   	my ($topic, $value) = split(/\s+/, $line);
      next if($value =~ /[a-z]+/i); # get only topics in format "path value"
      if($value =~ /\[/){
         my $data = $json->decode($value);
         $value = $data->{'e'}[0]{'v'};
      }
      if($topic =~ /\$SYS/){
         my @tuples = split('/', $topic);
         $topic = '/sensors/900/' . $inice->{$tuples[-1]};
      }

      printf "%s: %s => %s\n", scalar localtime, $topic, $value;
   	$dbh->do("INSERT INTO $dbtable (TOPIC, TIMESTAMP, VALUE) VALUES (?,?,?)", 
   	            undef, $topic, time, $value);
   }
   SUB->close();

   sleep 5;
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
