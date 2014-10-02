use warnings;
use strict;

# only for debug
use Data::Dumper;
sub dum { warn Dumper(@_)};


use Mojolicious::Lite;
use Mojo::IOLoop;
use Geras::Api;
use XHome::Sensor;

# Geras MQTT API
dum( "Init Geras ... " );
my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});
#$geras->clearCache;

# -----------------------

# Check payload every x seconds and publish mqtt packets
dum( "Init Loop ... " );
Mojo::IOLoop->recurring(1 => sub {
   my $loop = shift;
   my $events = $geras->fetchdata;
});

get '/' => sub {
   my $c = shift;
   
   $c->stash( rooms => $geras->series_unique(1) );

   my $sensors = [];
   $c->stash( sensors => $sensors );
   
   $c->render(template => 'index');
};

app->start;