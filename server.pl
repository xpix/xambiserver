use warnings;
use strict;

$ENV{CONFIGFILE} = 'cfg/sensors.cfg';

# only for debug
use Data::Dumper;
sub dum { warn Dumper(@_)};

use Mojolicious::Lite;
use Mojo::IOLoop;
use Geras::Api;
use XHome::Sensor;
use JSON::XS;

my $EVENTS  = [];
my $TYPES   = {};

# Geras MQTT API
dum( "Init Geras ... " );
my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});
#$geras->clearCache;

# -----------------------

sub _timedata {
   my $data = shift || [];
   
   my $timegrouped = {};
   map {
      # Group in 10 sec steps
      my @trible = split(//, $_->{'t'});
      pop @trible;
      my $mark = join('', @trible);
      push(@{$timegrouped->{$mark}}, $_);
   } @{$data->{e}};

   my $return = [];
   foreach my $timestamp (sort {$a <=> $b} keys %$timegrouped){
      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timegrouped->{$timestamp}->[0]->{'t'});
      my $sdata = {
         "Date" => sprintf('%02d.%02d.%04d', $mday, $mon+1, $year + 1900),
         "Time" => sprintf('%02d:%02d:%02d', $hour, $min, $sec),
      };         
      foreach my $item (@{$timegrouped->{$timestamp}}){
         my @elements = split(/\//, $item->{'n'});
         my $name = $elements[-1] eq 'power' ? 'Power' : 'Value'.$elements[-1];

         $TYPES->{$item->{'n'}} = XHome::Sensor->new({topic => $item->{'n'}})
            unless(exists $TYPES->{$item->{'n'}});
         my $sensor = $TYPES->{$item->{'n'}};
         $sdata->{$name} = $item->{'v'} / $sensor->display->{divider};
      }
      push(@$return, $sdata);   
   };

   $return;
}

sub _sensorgrp {
   my $data = shift || [];
   my $group = shift || '';

   my $return = [];
   my $sensorvalues = {};
   my $sensorHash = {};

   foreach my $topic (@{$data->{$group}}){
      my $sensor = XHome::Sensor->new({
         topic => $topic,
         geras => $geras,
      }) or die "Can't initialze Sensor with topic: $topic!";
      
      my $info = $sensor->info;
      
      push(@{$sensorHash->{$sensor->id}->{value}}, $info);

      unless(exists $sensorHash->{$sensor->id}->{name}){
         $sensorHash->{$sensor->id}->{sensor}   = $sensor->id;
         $sensorHash->{$sensor->id}->{name}     = sprintf('%s: %d',$sensor->type, $sensor->id);
         $sensorHash->{$sensor->id}->{type}     = $sensor->type;
         $sensorHash->{$sensor->id}->{text}     = sprintf('Last refresh: %s', scalar localtime($sensor->when));
         $sensorHash->{$sensor->id}->{info}     = $sensor->info;
      }

      $sensorHash->{$sensor->id}->{power}    = $info->{last}
         if($info->{valueid} eq 'power');
   }

   return [ values %{$sensorHash} ];
}

# Check payload every x seconds and publish mqtt packets
dum( "Init Loop ... " );

Mojo::IOLoop->recurring(1 => sub {
   my $loop = shift;
   my $events = $geras->fetchdata || [];
   foreach my $event (@$events){
      $event->{geras} = $geras;
      my $sensor = XHome::Sensor->new(
         $event
      );
      push(@$EVENTS, $sensor);
      # Trigger via websocket or other 
      # to inform webpage for new Events

   }
   $EVENTS = [];
});

get '/demo' => sub {
   my $c = shift;
   
   # Fill Stash ...
   $c->stash( rooms => $geras->groups );
   
   # Render Content
   $c->render(template => 'index');
};

get '/' => sub {
   my $c = shift;

   my $conf = Config::General->new($ENV{CONFIGFILE});
   my %cfg = $conf->getall;
   $c->stash( config => JSON::XS->new->utf8->encode( \%cfg ));
   
   # Render Content
   $c->render(template => 'demo');
};


get '/geras' => sub {
   my $c   = shift;
   my $sub = $c->param('sub') || die "No 'sub' parameter!";
   my @params = split(/,/, $c->param('subparams') || '');

   if(defined $c->param('type') and $c->param('type') eq 'sensorgrp'){
      $c->render(
         json => _sensorgrp( $geras->$sub(@params), $params[0] )
      );
   }
   elsif(defined $c->param('type') and $c->param('type') eq 'timedata'){
      $c->render(
         json => _timedata( $geras->$sub(@params) )
      );
   }

   else {
      $c->render(json => {
         $sub => $geras->$sub(@params),
      });
   }
   
};

get '/sensor' => sub {
   my $c   = shift;
   my $topic   = $c->param('topic') || die "No 'topic' parameter!";
   my $sub     = $c->param('sub') || die "No 'sub' parameter!";
   my $params  = split(/\|/, $c->param('subparams')) || ''
      if($c->param('subparams'));

   my $sensor = XHome::Sensor->new({
      topic => $topic,
      geras => $geras,
   }) or die "Can't initialze Sensor with topic: $topic!";

   $c->render(json => {
      topic => $topic,
      $sub => $sensor->$sub($params),
   });
};


app->start;
