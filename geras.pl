#!/usr/bin/env perl
use Data::Dumper;
sub dum { print Dumper(@_)};

use Geras::Api;
my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});

$ENV{CONFIGFILE} = 'xambiserver/cfg/sensors.cfg';

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
#dum( $geras->timewindow('/sensors/155/power',1410338021,1410338081) );# 1min
#dum( $geras->timewindow('/sensors/155/power','30s') );# 30sec
#dum( $geras->timewindow('/sensors/155/power','1m') );# 1min

#
## Shares
#dum( $geras->shares() );
#dum( $geras->shares('writeonly') );
#dum( $geras->series_delete('/sensors/152/power') );
#dum( $geras->share_delete('/d123p432/myshare') );

# Groups
#dum( $geras->groups_new('Arbeitszimmer', ['/sensors/155/power', '/sensors/155/0', '/sensors/155/1']) );
#dum( $geras->groups_new('groupname_second', []) );
#dum( $geras->groups('Arbeitszimmer') );
#dum( $geras->groups() );
#dum( $geras->groups_delete('/group/5zn8tpvdw3/unknown') );
#dum( $geras->groups_delete('Wohnzimmer') );
#dum( $geras->groups() );

# Funtions
#printf "Add series: 152 to groupname\n";
#dum( $geras->series_add_to_group(152, 'groupname' ) );
#dum( $geras->groups() );
#printf "Move series: 152 to groupname_second\n";
dum( $geras->groups() );
#dum( $geras->series_move_to_group('112,315', 'Wohnzimmer' ) );
#dum( $geras->groups() );
#printf "Remove series: 152 from groupname_second\n";
#dum( $geras->series_remove_from_group(112, 'Wohnzimmer' ) );
#dum( $geras->groups() );
#printf "Remove all groups\n";
#dum( $geras->groups_delete('groupname') );
#dum( $geras->groups_delete('groupname_second') );
#dum( $geras->groups() );


   
exit;
