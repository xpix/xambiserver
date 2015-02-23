#!/usr/bin/perl

$ENV{CONFIGFILE} = 'cfg/sensors.cfg';

use strict;
use warnings;

use AnyEvent;
use AnyEvent::SerialPort;
use XAmbi::Api;
use XHome::Sensor;

use Data::Dumper;
sub dum { warn sprintf("DEBUG: %s\n", Dumper(@_)); };

# Autoflush on
$| = 1;

print STDERR "Init ...\n";

my $port = shift || '/dev/ttyAMA0';

# Geras MQTT API
my $xambi = XAmbi::Api->new({
   host   => 'localhost',
});
   
#--------------------------
my $cv = AnyEvent->condvar;

# Timer
my $w = AnyEvent->timer (after => 5, interval => 60, cb => sub {
   my $node = 901;

   # Load
   my $stats   = `cat /proc/loadavg`; chomp $stats;
   my($avg_1, $avg_5, $avg_15) = split(/\s+/, $stats);

   # memory
   $stats   = `cat /proc/meminfo`; chomp $stats;
   my($memfree) = $stats =~ /MemFree\:\s+(\d+)\s+/;
   my($swpfree) = $stats =~ /SwapFree\:\s+(\d+)\s+/;

   # cpu temperature
   my $temp   = int(`cat /sys/class/thermal/thermal_zone0/temp` / 10);

   my $PAYLOAD = [];
   push($PAYLOAD, 
      { sprintf( '/sensors/%d/power',  $node) => $temp },
      { sprintf( '/sensors/%d/0',      $node) => $avg_1 },
      { sprintf( '/sensors/%d/1',      $node) => $memfree },
      { sprintf( '/sensors/%d/2',      $node) => $swpfree },
   );   

   $xambi->publish($PAYLOAD);
});

# SerialPort read Event
my $hdl = 
   AnyEvent::SerialPort->new(
     serial_port => $port,
   );

# we assume a request starts with a single line
my @start_request; 
@start_request = (line => sub {
   my ($hdl, $line) = @_;
   printf STDERR "%s %s\n", scalar localtime(), $line 
      if($line);
   handle_message($line);

   # push next request read, possibly from a nested callback
   $hdl->push_read (@start_request);
});
# now push the first @start_request
$hdl->push_read(@start_request);

$cv->wait;

exit;

sub handle_message {
   my $line = shift || return;
   chomp $line;
   
   my $PAYLOAD = [];
   
   my ($node, $paramsize, $milliVolt, @values) = split(/\s+/, $line);
   return 0 if($node =~ /[a-z]+/i);
   return 0 if(not scalar @values);
	return 0 if(not checkValues($node, $milliVolt, @values));

   # save milliVolt for sensor
   push($PAYLOAD, {
      sprintf( '/sensors/%d/power', $node) => $milliVolt,
   });   

   # save data for sensor
   my $i = 0;
   foreach my $value (@values){
      push($PAYLOAD, {
         sprintf( '/sensors/%d/%d', $node, $i++) => $value,
      });   
   }

   $xambi->publish($PAYLOAD);   
}

sub checkValues {
	my ($node, @values) = @_;
	my $i = 0;
   foreach my $value (@values){ 
	   my $indexer = ($i==0 ? 'power' : $i-1);
      my $topic = "/sensor/$node/$indexer";
		my $sensor = XHome::Sensor->new({
			topic => $topic,
			geras => $xambi,
		});
      $i++;
	}
	return 1;
}