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
   topic => '/sensors/400/0',
});

$geras->clearCache();


#dum( $sensor->value(1523) );
dum( $sensor->last );

exit;
