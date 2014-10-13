package XHome::Sensor;

use warnings;
use strict;

use Data::Dumper;
sub dum { printf "DEBUG: %s\n", Dumper(@_); };

my $ERRORS;
#===============================================================================
=pod

=head1 NAME

XHome::Sensor - Module to get an sensor as object oriented 

=head1 SYNOPSIS

   my $geras = Geras::Api->new({
      apikey => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      host   => 'geras.1248.io',
   });

   my $sensorobj = XHome::Sensor->new({
      topic => $event->{topic},
      when => $event->{when},
      value => $event->{value},
      geras => $geras,
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

   # API Data
   $self->topic( delete $args->{'topic'} || die "No Topic in new!" );
   $self->when( delete $args->{'when'} || time);
   $self->value( delete $args->{'value'} || 0 );
   $self->geras( delete $args->{'geras'} || 0 );

   return $self;
}

#-------------------------------------------------------------------------------
sub type {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $id    = shift || $obj->{id} || die "No Id found!";

   $obj->{_cachedTxt} = `cat cfg/sensortypes.cfg`
      unless(defined $obj->{_cachedTxt});

   my $sensortypes = eval( '{'.$obj->{_cachedTxt}.'}' );
   foreach my $typename (keys %$sensortypes){
      my $sector = $sensortypes->{$typename};
      if($id >= $sector->[0] and $id <= $sector->[1]){
         return $typename;
      }
   }
   die "Cannot find type for id $id !";
}


#-------------------------------------------------------------------------------
sub topic {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   if(defined $_[0]){
      $obj->{topic} = $_[0];
      my ($id) = $obj->{topic} =~ /\/(\d+)\//si;
      die "Problem to read topic: ".$obj->{topic}
         unless($id);
      $obj->id($id);
   }
   return $obj->{topic};
}

#-------------------------------------------------------------------------------
sub value {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   $obj->{value} = $_[0] if(defined $_[0]);
   return $obj->{value};
}

#-------------------------------------------------------------------------------
sub now {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   return $obj->value;
}

#-------------------------------------------------------------------------------
sub when {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   $obj->{when} = $_[0] if(defined $_[0]);
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
   return $obj->{geras}->series_group($obj->id);
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