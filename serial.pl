#!/usr/bin/perl

$ENV{CONFIGFILE} = 'cfg/sensors.cfg';

use strict;
use warnings;

use AnyEvent;
use AnyEvent::SerialPort;
use Geras::Api;
use XHome::Sensor;

use Data::Dumper;
sub dum { warn sprintf("DEBUG: %s\n", Dumper(@_)); };

print STDERR "Init ...\n";
# Geras MQTT API
my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});
#$geras->clearCache;
   
#--------------------------
my $cv = AnyEvent->condvar;

# SerialPort read Event
my $hdl = 
   AnyEvent::SerialPort->new(
     serial_port => '/dev/ttyUSB0',
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

   $geras->publish($PAYLOAD);   
}

sub checkValues {
	my ($node, @values) = @_;
	my $i = 0;
   foreach my $value (@values){ 
	   my $indexer = ($i==0 ? 'power' : $i-1);
      my $topic = "/sensor/$node/$indexer";
		my $sensor = XHome::Sensor->new({
			topic => $topic,
			geras => $geras,
		});
		if(not defined $sensor->value($value)){
			return 0;
		}
      $i++;
	}
	return 1;
}