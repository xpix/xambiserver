#!/usr/bin/env perl
use Data::Dumper;
sub dum { print Dumper(@_)};

use Geras::Api;
my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});

$geras->clearCache();

# Publish
#dum( $geras->publish('/sensors/155/power', 4444) );
#dum( $geras->publish(
#   [
#      { '/sensors/155/0' => 5555 },
#      { '/sensors/155/1' => 6666 },
#   ]
#   ) 
#);
#sleep 1;


#
## Series
#dum( $geras->series() );
#dum( $geras->series_unique(1) );
#dum( $geras->series_unique(1, '/sensors/xxx') );
#dum( $geras->series('155') );
#dum( $geras->lastvalue('/sensors/155/power') );
#dum( $geras->rollup('/sensors/155/power','min','1d') );
#dum( $geras->rollup('/sensors/155/power','max','1d') );

# Groups
#dum( $geras->groups_new('Arbeitszimmer', ['/sensors/155/power', '/sensors/155/0', '/sensors/155/1']) );
#dum( $geras->groups_new('groupname_second', []) );
#dum( $geras->groups('Arbeitszimmer') );
dum( $geras->groups() );
#dum( $geras->groups_delete('/group/5zn8tpvdw3/unknown') );
#dum( $geras->groups_delete('Garten') );
#dum( $geras->groups() );

# Funtions
#printf "Add series: 152 to groupname\n";
#dum( $geras->series_add_to_group(152, 'groupname' ) );
#dum( $geras->groups() );
#printf "Move series: 152 to groupname_second\n";
#dum( $geras->groups('/group/5zn8tpvdw3/Garten') );
#dum( $geras->series_move_to_group('155', 'Garten' ) );
#dum( $geras->groups() );
#dum( $geras->series_move_to_group('400', 'Garten' ) );
#dum( $geras->groups() );
#printf "Remove series: 152 from groupname_second\n";
#dum( $geras->series_remove_from_group(112, 'Wohnzimmer' ) );
#dum( $geras->groups() );
#printf "Remove all groups\n";
#dum( $geras->groups_delete('groupname') );
#dum( $geras->groups_delete('groupname_second') );
#dum( $geras->groups() );


   
exit;