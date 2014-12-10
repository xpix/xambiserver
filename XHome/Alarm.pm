package XHome::Alarm;

use warnings;
use strict;

use Config::General;
use Mail::SendEasy;

use Data::Dumper;
sub dum { "DEBUG: %s\n", Dumper(@_); };

my $ERRORS;
#===============================================================================
=pod

=head1 NAME

XHome::Alarm - Module to set alarm level and call alarm, 
alarms and types are defined in config file:

   <alarmtype MAIL>
      from 'xambi@foo.de'
      to 'xpix@bar.de'
   </alarmtype>


=head1 SYNOPSIS

   my $sensorobj = XHome::Alarm->new({
      topic => $event->{topic},
   });

   $sensorobj->check(); # check if alaram happend

   $sensorobj->alarm(); # call alarm
   

=head1 DESCRIPTION

Package to manage Senors.

=cut

#-------------------------------------------------------------------------------
sub new {
#-------------------------------------------------------------------------------
   my $class = shift;
   my $args  = shift;
   my $self  = { };

   bless($self, $class);

   # API Data
   $self->sensor( delete $args->{'sensor'} )   || die "No Sensor obj in new!";

   return $self;
}

#-------------------------------------------------------------------------------
sub sensor {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   $obj->{sensor} = $_[0] if(defined $_[0]);
   return $obj->{sensor};
}

#-------------------------------------------------------------------------------
sub lastalarm {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   $obj->{lastalarm} = $_[0] if(defined $_[0]);
   return $obj->{lastalarm} || 0;
}


#-------------------------------------------------------------------------------
sub check {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $value = shift;


   my $sensor = $obj->sensor;
   my $id = $obj->sensor->id;
   my $cfg = $sensor->cfg;   
   my $cfg_alarm = $cfg->{alarms}{'Node_'.$sensor->id}
      or return 1;

   # Change value to human readable format   
   if(exists $sensor->display->{'format'}){
      $value = sprintf($sensor->display->{'format'}, $value);
   }

   my $topic = $sensor->topic;
   my $groupname = $sensor->group('notFull');
   my $msg = $cfg_alarm->{message};
   $msg =~ s/(\$\w+)/$1/eeg;
die dum($msg, $sensor->config);
   if(defined $value and $value < $cfg_alarm->{value}->[0] and $value > $cfg_alarm->{value}->[1]){
      # Alarm if lastalarm - timetolive greather than actual time
      if($obj->lastalarm < (time - $cfg_alarm->{ttl})){
         # Send via types
         foreach my $type (@{$cfg_alarm->{type}}){
            $obj->$type($msg);
         }
         $obj->lastalarm( time ); # set last alarm timepoint
      }
   }

   return 1;
}

#-------------------------------------------------------------------------------
sub SMS {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $msg   = shift || die "No Message!";

   my $cfg   = $obj->sensor->cfg->{alarmtype}->{SMS}
      or die "Can't find alarm configuration for type: SMS!";
   
   my $url = sprintf('https://api.twilio.com/2010-04-01/Accounts/%s/Messages.json', $cfg->{account_sid});
   my $curl = sprintf(
      "curl -s -X POST %s --data-urlencode 'To=%s'  --data-urlencode 'From=%s'  --data-urlencode 'Body=%s' -u %s:%s",
         $url, $cfg->{to}, $cfg->{from}, $msg, $cfg->{account_sid}, $cfg->{auth_token}
   );
   return `$curl`;
}

#-------------------------------------------------------------------------------
sub MAIL {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $msg   = shift || die "No Message!";

   my $cfg   = $obj->sensor->cfg->{alarmtype}->{MAIL}
      or die "Can't find alarm configuration for type: MAIL!";

   my $mail = Mail::SendEasy->new(
     smtp => $cfg->{host},
     port => $cfg->{port},
     user => $cfg->{user},
     pass => $cfg->{pass},
   );      

   my $status = $mail->send(
     from    => $cfg->{from},
     from_title => 'Xambinode '.$obj->sensor->id,
     to      => $cfg->{to},
     subject => "Mail::SendEasy - Perl Test",
     msg     => $msg,
   ) || die ($mail->error, Mail::SendEasy::error);

   return 1;
}

#-------------------------------------------------------------------------------
sub cfg {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $file  = shift || return $obj->{cfg};

   if($file){
      my $conf = Config::General->new($file);
      my %config = $conf->getall;
      $obj->{cfg} = \%config;
   }

   return $obj->{cfg};
}


#-------------------------------------------------------------------------------
sub error {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $msg   = shift || return $ERRORS;

   warn $msg;
   $ERRORS = []
      if(not defined $ERRORS);

   push(@$ERRORS, $msg);
   
   return undef;
}

1;