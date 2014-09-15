use warnings;
use strict;

# only for debug
use Data::Dumper;
sub dum { print Dumper(@_)};


use Mojolicious::Lite;
use Mojo::IOLoop;
use AnyEvent::SerialPort;
use Geras::Api;

# Geras MQTT API
my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});
$geras->clearCache;

# SerialPort read Event
my $hdl = 
   AnyEvent::SerialPort->new(
     serial_port => '/dev/ttyUSB0',
   );

# Check payload every x seconds and publish mqtt packets
my $PAYLOAD = [];
Mojo::IOLoop->recurring(10 => sub {
   if(scalar @$PAYLOAD){
	   $geras->publish($PAYLOAD);   
      $PAYLOAD = [];
   }
});

get '/' => sub {
   my $c = shift;
   
   $c->stash( rooms => $geras->series_unique(1) );

   my $sensors = [];
   foreach my $sensortopic (@{$geras->series}){
      my $value = $geras->lastvalue($sensortopic);
      push(@$sensors, {
         name => $sensortopic,
         werte => [
            { 
               name => $sensortopic,
               value => values $value,
            },
         ],
      });
      
   }
   $c->stash( sensors => $sensors );
   
   $c->render(template => 'index');
};

get '/events' => sub {
  my $self = shift;

  # Emit "msg" event for every new IRC message
  $self->res->headers->content_type('text/event-stream');

  my $cv = AnyEvent->condvar;
  
  # read the response line
   $hdl->push_read (line => sub {
      my ($hdl, $line) = @_;
      warn "Received '$line'";
      handle_message($line);
      $self->write("event:msg\ndata: $line\n\n");
      $cv->send;
   });
};

app->start;

sub handle_message {
   my $line = shift || return;
   chomp $line;

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
}
