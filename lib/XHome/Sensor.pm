package XHome::Sensor;

use warnings;
use strict;

use Carp;

use XHome::Alarm;
use Config::General;


use Data::Dumper;
sub dum { warn sprintf("DEBUG: %s\n", Dumper(@_)); };

my $ERRORS;
#===============================================================================
=pod

=head1 NAME

XHome::Sensor - Module to get an sensor as object oriented

=head1 SYNOPSIS

   my $xambi = XAmbi::Api->new({
      host   => 'localhost',
   });

   my $sensorobj = XHome::Sensor->new({
      topic => $event->{topic},
      when => $event->{when},
      value => $event->{value},
      geras => $xambi,
   });
   print
      $sensorobj->type, # i.e. Temperature
      $sensorobj->now, # i.e. last value
      $sensorobj->id(), # i.e. 155
      $sensorobj->topic(), # i.e. /sensors/155/power
   ;

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

   my $time = time;

   # API Data
   $self->cfg(   delete $args->{'configfile'} || $ENV{CONFIGFILE} ) || die "Can't read config!";
   $self->topic( delete $args->{'topic'} )   || die "No Topic in new!";
   $self->when ( delete $args->{'when'} || $time );
   $self->value( delete $args->{'value'} )   || 0;
   $self->geras( delete $args->{'geras'} )   || 0;

   return $self;
}
=pod

Lots of methods to return probertys.

  $sensorobj->display(); # Confighash to display this topic
  $sensorobj->divider(); # Divider for raw value
  $sensorobj->name();    # Name for this value in sensor
  $sensorobj->cfg();     # complete Confighashfor all Sensors
  $sensorobj->config();  # Confighash for for this sensor type
  $sensorobj->idx();     # gets Value index or power
  $sensorobj->info();    # get a hash with complete info's about this sensor
  $sensorobj->type();    # return the type of this sensor value
  $sensorobj->suffix();  # return the suffix of this sensor value
  $sensorobj->topic($t); # set topic
  $sensorobj->value($v); # set or get Value
  $sensorobj->now();     # get now value
  $sensorobj->last();    # get last Value
  $sensorobj->when();    # last change of this sensor value in unixtime
  $sensorobj->id();      # get or set id from topic
  $sensorobj->valueid(); # get or set valueid
  $sensorobj->geras();   # get or set xambi object
  $sensorobj->group();   # get group from sensor object

=cut

sub display { my $obj = shift; $obj->cfg->{display}{$obj->name} };
sub divider { my $obj = shift; $obj->display->{divider} };
sub name    { my $obj = shift; $obj->config->{ValNames}->[$obj->idx] };
sub suffix  { my $obj = shift; $obj->display->{suffix} };

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
sub config {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   return $obj->cfg->{sensor}->{$obj->type};
}

# /sensors/315/power = 0; ../315/0 = 1 ...
#-------------------------------------------------------------------------------
sub idx {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $lastChar = substr(lc $obj->valueid, -1); # /r or 0 or 1 or 2 ...
   return ($lastChar eq 'r' ? 0 : int($lastChar)+1);
}

#-------------------------------------------------------------------------------
sub info {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";

   {
      type     => $obj->type,
      topic    => $obj->topic,
      id       => $obj->id,
      valueid  => $obj->valueid,
      last     => $obj->last,
      when     => $obj->when,
      nidx     => $obj->idx,
      name     => $obj->name,
      config   => $obj->config,
      display  => $obj->display,
   };
}


#-------------------------------------------------------------------------------
sub type {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $id    = shift || $obj->{id} || die "No Id found!";

   my $sensortypes = $obj->cfg->{sensor};
   foreach my $typename (keys %$sensortypes){
      my $sector = $sensortypes->{$typename};
      if($id >= $sector->{startNodeId} and $id <= $sector->{endNodeId}){
         return $typename;
      }
   }
   die "Cannot find type for id $id !";
}


#-------------------------------------------------------------------------------
sub topic {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   if($_[0]){
      $obj->{topic} = shift;
      my ($id, $valueid) = $obj->{topic} =~ /\/(\d+)\/(\S+)/si;
      die "Problem to read topic: ".$obj->{topic}
         unless($id);
      $obj->id($id);
      $obj->valueid($valueid);
   }
   return $obj->{topic};
}

#-------------------------------------------------------------------------------
sub value {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
	my $val 	 = shift || undef;

   if(defined $val and ref $obj->display eq 'HASH'){
		# Check Value
		my ($div, $min, $max) = ($obj->divider, $obj->display->{minimumValue}, $obj->display->{maximumValue});
		my $value = $val / $div;

      # Alarmobject init
      my $alarmobj = XHome::Alarm->new({
         sensor => $obj,
      }) or die "Cannot init XHome::Alarm";
      # Check alarm status
      $alarmobj->check($value);
      $alarmobj = undef;

		if(defined $min and defined $max and ($value < $min or $value > $max)){
			return $obj->error(sprintf("Value %s for Node %s are not correct! Value not between %s to %s!",
										$value, $obj->topic, $min, $max));
		}
		$obj->{value} = $val;
   }

   return $obj->{value};
}

#-------------------------------------------------------------------------------
sub now {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   return $obj->value;
}

#-------------------------------------------------------------------------------
sub last {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   $obj->when(time);
   return $obj->geras->lastvalue( $obj->topic );
}

#-------------------------------------------------------------------------------
sub when {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   $obj->{when} = $_[0] if(defined $_[0]);
   $obj->geras->lastvalue( $obj->topic )
      if($obj->geras and not defined $obj->{when});
   return $obj->{when};
}

#-------------------------------------------------------------------------------
sub id {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   $obj->{id} = $_[0] if(defined $_[0]);
   return $obj->{id};
}

#-------------------------------------------------------------------------------
sub valueid {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   $obj->{valueid} = $_[0] if(defined $_[0]);
   return $obj->{valueid};
}

#-------------------------------------------------------------------------------
sub geras {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   $obj->{geras} = $_[0] if(defined $_[0]);
   return $obj->{geras};
}

#-------------------------------------------------------------------------------
sub group {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $notFull = shift || 0;

   my $grp = $obj->{geras}->series_group($obj->id);

   my $name = (split(/\//, $grp))[-1];
   return $name if($notFull);
   return $grp;
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