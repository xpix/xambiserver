#!/usr/bin/perl

# This small example script shows how to do non-blocking
# reads from a file handle.

use AnyEvent;
use AnyEvent::SerialPort;
use Geras::Api;

print "Init ...\n";
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
   warn $line;
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
   return 0 if(not scalar @values);

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
