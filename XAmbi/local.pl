#!/usr/bin/env perl
use Data::Dumper;
sub dum { print Dumper(@_)};

use XAmbi::Api;
my $xambi = XAmbi::Api->new({
   host   => '127.0.0.1',
   port   => '3080',
   noproxy=> 1,
});

$xambi->clearCache();

# Publish
#dum( $xambi->publish('/sensors/155/power', 4444) );
#dum( $xambi->publish(
#   [
#      { '/sensors/155/0' => 5555 },
#      { '/sensors/155/1' => 6666 },
#   ]
#   ) 
#);
#sleep 1;


#
## Series
dum( $xambi->series() );
#dum( $xambi->series_unique(1) );
#dum( $xambi->series_unique(1, '/sensors/xxx') );
#dum( $xambi->series('155') );
#dum( $xambi->lastvalue('/sensors/155/power') );
#dum( $xambi->rollup('/sensors/155/power','avg','30m') );
#dum( $xambi->rollup('/sensors/155/power','min','1d') );

# Groups
#dum( $xambi->groups_new('Arbeitszimmer', ['/sensors/155/power', '/sensors/155/0', '/sensors/155/1']) );
#dum( $xambi->groups_new('groupname_second', []) );
dum( $xambi->groups() );
dum( $xambi->groups('Garten') );
dum( $xambi->groups_delete('Wohnzimmer') );
dum( $xambi->groups() );

# Funtions
#printf "Add series: 152 to groupname\n";
#dum( $xambi->series_add_to_group(152, 'groupname' ) );
#dum( $xambi->groups() );
#printf "Move series: 152 to groupname_second\n";
#dum( $xambi->groups('/group/5zn8tpvdw3/Garten') );
#dum( $xambi->series_move_to_group('155', 'Garten' ) );
#dum( $xambi->groups() );
#dum( $xambi->series_move_to_group('400', 'Garten' ) );
#dum( $xambi->groups() );
#printf "Remove series: 152 from groupname_second\n";
#dum( $xambi->series_remove_from_group(112, 'Wohnzimmer' ) );
#dum( $xambi->groups() );
#printf "Remove all groups\n";
#dum( $xambi->groups_delete('groupname') );
#dum( $xambi->groups_delete('groupname_second') );
#dum( $xambi->groups() );


   
exit;
