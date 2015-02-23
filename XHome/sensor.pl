#!/usr/bin/env perl

$ENV{CONFIGFILE} = 'cfg/sensors.cfg';


use Data::Dumper;
sub dum { print Dumper(@_)};

use XHome::Sensor;
use XAmbi::Api;

my $xambi = XAmbi::Api->new({
   host   => 'localhost',
});


my $sensor = XHome::Sensor->new({
   topic => '/sensors/411/0',
   geras => $xambi,
});



dum( $sensor->value(1) );
dum( $sensor->value() );

exit;
