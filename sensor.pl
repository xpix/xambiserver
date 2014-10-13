#!/usr/bin/env perl
use Data::Dumper;
sub dum { print Dumper(@_)};

use XHome::Sensor;
use Geras::Api;

my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});

my $sensor = XHome::Sensor->new({
   topic => '/sensors/155/power',
   when  => time - 100,
   value => 6666,
   geras => $geras,
});

#dum( $geras->groups_new('sensorgroup', ['/sensors/155/power', '/sensors/155/0']) );
dum( $geras->groups );


dum( $sensor->group );
dum( $sensor->type );
dum( $sensor->topic );
dum( $sensor->id );
dum( $sensor->when );
dum( $sensor->value );

exit;
