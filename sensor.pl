#!/usr/bin/env perl

$ENV{CONFIGFILE} = 'cfg/sensors.cfg';


use Data::Dumper;
sub dum { print Dumper(@_)};

use XHome::Sensor;
use Geras::Api;

my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});

my $sensor = XHome::Sensor->new({
   topic => '/sensors/315/0',
   geras => $geras,
});



dum( $sensor->value(100) );
dum( $sensor->info );
dum( $sensor->group );
dum( $sensor->type );
dum( $sensor->topic );
dum( $sensor->id );
dum( $sensor->when );
dum( $sensor->value );

exit;
