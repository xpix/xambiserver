#!/usr/bin/env perl
use Data::Dumper;
sub dum { print Dumper(@_)};

use Geras::Api;
my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});

# Publish
#dum( $geras->publish('/sensors/155/power', 4444) );
#dum( $geras->publish(
#   [
#      { '/sensors/155/0' => 5555 },
#      { '/sensors/155/1' => 6666 },
#   ]
#   ) 
#);
#
## Series
#dum( $geras->series() );
dum( $geras->series_unique(1) );
#dum( $geras->series('155') );
#dum( $geras->lastvalue('/sensors/155/power') );
#dum( $geras->rollup('/sensors/155/power','min','1d') );
#dum( $geras->rollup('/sensors/155/power','max','1d') );
#dum( $geras->timewindow('/sensors/155/power',1410338021,1410338081) );# 1min
#
## Shares
#dum( $geras->shares() );
#dum( $geras->shares('writeonly') );
# dum( $geras->series_delete('/sensors/152/power') );
# dum( $geras->share_delete('/d123p432/myshare') );



exit;
