use warnings;
use strict;

# only for debug
use Data::Dumper;
sub dum { warn Dumper(@_)};

use Mojolicious::Lite;
use Mojo::IOLoop;
use Geras::Api;
use XHome::Sensor;

my $EVENTS = [];

# Geras MQTT API
dum( "Init Geras ... " );
my $geras = Geras::Api->new({
   apikey => '9ca6362e6051ec2588074f23a7fb7afe',
   host   => 'geras.1248.io',
});
#$geras->clearCache;

# -----------------------

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

      $sensorHash->{$sensor->id} = {
         sensor   => $sensor->id,
         name     => sprintf('Node: %d, %s', $sensor->id, $sensor->type),
         type     => $sensor->type,
         text     => sprintf('Last refresh: %s', scalar localtime($sensor->when)),
      } unless(exists $sensorHash->{$sensor->id});

      push(@{$sensorHash->{$sensor->id}->{value}}, $sensor->info);
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
#dum($sensor);
      # Trigger via websocket or other 
      # to inform webpage for new Events

   }
   $EVENTS = [];
});

get '/' => sub {
   my $c = shift;
   
   # Fill Stash ...
   $c->stash( rooms => $geras->groups );
   
   # Render Content
   $c->render(template => 'index');
};

get '/demo' => sub {
   my $c = shift;
   
   # Render Content
   $c->render(template => 'demo');
};


get '/geras' => sub {
   my $c   = shift;
   my $sub = $c->param('sub') || die "No 'sub' parameter!";
   my @params = split(/,/, $c->param('subparams'));

   if($c->param('type') eq 'sensorgrp'){
      $c->render(
         json => _sensorgrp( $geras->$sub(@params), $params[0] )
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
