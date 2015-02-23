package XHome::Alarm;

use warnings;
use strict;

use Config::General;
use Mail::SendEasy;

use Data::Dumper;
sub dum { warn sprintf("DEBUG: %s\n", Dumper(\@_)); };

$ENV{LASTALARMS} = "cfg/lastalarms.cfg";
$ENV{ALARMS}     = "cfg/alarms.cfg";

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

=head1 METHODS

  $sensorobj->lastalarm;   # get time of last alarm
  $sensorobj->MAIL($msg);  # send alarm mail 
  $sensorobj->SMS($msg);   # send alarm sms
  $sensorobj->range;       # get alarm range
  $sensorobj->sensor;      # get sensor object

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

   # Load Configuration
   $self->cfg($ENV{ALARMS});
     
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

   die "ENV{ALARMFILE} not set!" unless($ENV{LASTALARMS});
   my $conf = Config::General->new($ENV{LASTALARMS});
   my %config = $conf->getall;

   if(defined $_[0]){
      my $alarmtime = shift;

      $config{'lastalarm'}{$obj->sensor->id} = $alarmtime;
      $conf->save_file($ENV{LASTALARMS}, \%config);
   }
   return $config{'lastalarm'}{$obj->sensor->id} || 0;
}

#-------------------------------------------------------------------------------
sub range {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $sensor = $obj->sensor;
   my $cfg = $obj->cfg;  
   my $cfg_alarm = $cfg->{alarms}{$sensor->type}
      or return;
   return $cfg_alarm->{value};
}


#-------------------------------------------------------------------------------
sub check {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $value = shift;

   my $sensor = $obj->sensor;
   my $id = $obj->sensor->id;
   my $cfg = $obj->cfg;  

   # Check for alarm config or global (alarm for every Sensor i.e. Power) alarm config
   my $cfg_alarm = $cfg->{alarms}{$sensor->type};
   $cfg_alarm = (ref $cfg->{alarms}{$sensor->name} and $cfg->{alarms}{$sensor->name}{global} ? $cfg->{alarms}{$sensor->name} : $cfg_alarm);
   return 0 if(not $cfg_alarm);

   if(exists $cfg_alarm->{name} and $cfg_alarm->{name} ne $sensor->name){
      return 1;
   }
   # Test only on value in array if valueidx set
   if($cfg_alarm->{idx} and $sensor->valueid != $cfg_alarm->{idx}){
      return 0;
   }

   # Change value to human readable format  
   if(exists $sensor->display->{'format'}){
      $value = sprintf($sensor->display->{'format'}, $value);
   }

   my $topic = $sensor->topic;
   my $groupname = $sensor->group('notFull') || 'unknown';
   my $msg = $cfg_alarm->{message};
   $msg =~ s/(\$\w+)/$1/eeg;

   if(defined $value and $value <= $cfg_alarm->{value}->[0] and $value >= $cfg_alarm->{value}->[1]){
      # Alarm if lastalarm - timetolive greather than actual time
      if($obj->lastalarm < (time - $cfg_alarm->{ttl})){
         # Send via types
         my $alarms = (ref $cfg_alarm->{type} eq 'ARRAY' ? $cfg_alarm->{type} : [$cfg_alarm->{type}]);
         foreach my $type (@$alarms){
            eval{ $obj->$type($msg) };
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
dum($msg);
   my $cfg   = $obj->cfg->{alarmtype}->{SMS}
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

   my $cfg   = $obj->cfg->{alarmtype}->{MAIL}
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