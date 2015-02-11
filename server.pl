#!/usr/bin/perl

use warnings;
use strict;

$ENV{CONFIGFILE}        = 'cfg/sensors.cfg';
$ENV{CONFIGFILE_USERS}  = 'cfg/users.cfg';

# only for debug
use Data::Dumper;
sub dum { warn Dumper(@_)};

use Mojolicious::Lite;
use Mojo::IOLoop;
use XAmbi::Api;
use XHome::Sensor;
use JSON::XS;

my $EVENTS  = [];
my $TYPES   = {};

# Geras MQTT API
dum( "Init Geras ... " );
my $xambi = XAmbi::Api->new({
   host   => '127.0.0.1',
   port   => 3080,
   noproxy=> 1,
});
$xambi->clearCache;

# -----------------------

sub _seriestypes {
   my $data = shift || [];

   my $return = {};   
   
   foreach my $topic (@$data){
      my $sensor = XHome::Sensor->new({
         topic => $topic.'/power',
         geras => $xambi,
      }) or die "Can't initialze Sensor with topic: $topic!";
      $return->{$sensor->id} = $sensor->group(1);
   }
   
   return $return;
}

sub _timedata {
   my $data = shift || [];
   
   my $timegrouped = {};
   map {
      # Group in 10 sec steps
      my @trible = split(//, $_->[1]);
      pop @trible;
      my $mark = join('', @trible);
      push(@{$timegrouped->{$mark}}, $_);
   } @{$data};

   my $return = [];
   foreach my $timestamp (sort {$a <=> $b} keys %$timegrouped){
      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timegrouped->{$timestamp}->[0][1]);
      my $sdata = {
         "Date" => sprintf('%02d.%02d.%04d', $mday, $mon+1, $year + 1900),
         "Time" => sprintf('%02d:%02d:%02d', $hour, $min, $sec),
         "Stamp" => $timegrouped->{$timestamp}->[0][1],
      };         
      foreach my $item (@{$timegrouped->{$timestamp}}){
         my ($texttime, $timestamp, $topic, $value) = @$item;
         my @elements = split(/\//, $topic);
         my $name = $elements[-1] eq 'power' ? 'Power' : 'Value'.$elements[-1];

         $TYPES->{$topic} = XHome::Sensor->new({topic => $topic})
            unless(exists $TYPES->{$topic});
         my $sensor = $TYPES->{$topic};
         $sdata->{$name} = sprintf("%.3f", $value / ($sensor->display->{divider} || 1));

         if(my $range = $sensor->{alarmobj}->range()){
            $sdata->{'Alarm'} = $range->[0];
         }
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
      next unless($topic);

      my $sensor = XHome::Sensor->new({
         topic => $topic,
         geras => $xambi,
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
   my $events = $xambi->fetchdata || [];
   foreach my $event (@$events){
      $event->{geras} = $xambi;
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
   $c->stash( rooms => $xambi->groups );
   
   # Render Content
   $c->render(template => 'index');
};

get '/' => sub {
   my $c = shift;

   my %cfg  = Config::General->new($ENV{CONFIGFILE})->getall;
   my %ucfg = Config::General->new($ENV{CONFIGFILE_USERS})->getall;

   if(my ($user, $password) = split(/\:/, $c->req->url->to_abs->userinfo)){
      my $login = 0;
      map{ $login = 1 if($_ eq $user and $ucfg{'user'}{$_}{'password'} eq $password); } keys %{$ucfg{'user'}};

      if($login){
         # Render Content
         $c->stash( 
            config => JSON::XS->new->utf8->encode( \%cfg ),
            perl_cfg => \%cfg,   
         );
         return $c->render(template => 'demo');
      }
   }
   
   # Require authentication
   $c->res->headers->www_authenticate('Basic');
   $c->render(text => 'Authentication required!', status => 401);
};


get '/geras' => sub {
   my $c   = shift;
   my $sub = $c->param('sub') || die "No 'sub' parameter!";
   my @params = split(/,/, $c->param('subparams') || '');
   my $data = $xambi->$sub(@params);

   if(defined $c->param('type') and $c->param('type') eq 'sensorgrp'){
      $c->render(
         json => _sensorgrp( $data, $params[0] )
      );
   }
   elsif(defined $c->param('type') and $c->param('type') eq 'timedata'){
      $c->render(
         json => _timedata( $data )
      );
   }
   elsif(defined $c->param('type') and $c->param('type') eq 'seriestypes'){
      $c->render(
         json => _seriestypes( $data )
      );
   }

   else {
      $c->render(json => {
         $sub => $xambi->$sub(@params),
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
      geras => $xambi,
   }) or die "Can't initialze Sensor with topic: $topic!";

   $c->render(json => {
      topic => $topic,
      $sub => $sensor->$sub($params),
   });
};


app->start;
