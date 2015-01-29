package Geras::Api;

use warnings;
use strict;

use Carp;
use LWP::UserAgent;
use JSON::XS;
use URI::Escape;
use IPC::ShareLite qw( :lock );
#use Cache::Memory;
#use Cache::File;
use CHI;

use Data::Dumper;
sub dum { warn Dumper(@_) };

my $timeWindow = {
   s => 1, # second
   m => 60, # minute
   h => 3600, # hour
   d => 24 * 3600, # day
   w => 7 * 24 * 3600, # week
};

my $ERRORS;
#===============================================================================
=pod

=head1 NAME

Geras::Api - Module to get a all data from geras.1248.io.

=head1 SYNOPSIS

  my $geras = Geras::Api->new({
   apikey  => 'kjdahdkjhasdlkj...'}
  );
  my $list = $geras->series();
  confess $list->error() if($list->error());

=head1 DESCRIPTION

Package to manage API Calls via http json to geras api.

=cut

#-------------------------------------------------------------------------------
sub new {
#-------------------------------------------------------------------------------
   my $class = shift;
   my $args  = shift;
   my $self  = { };

   bless($self, $class);

   # API Data
   $self->{'apikey'}  = delete $args->{'apikey'} || confess "No Apikey in new!";
   $self->{'host'}    = delete $args->{'host'}   || 'geras.1248.io';

   #$self->{'cache'}   = Cache::Memory->new(
   #$self->{'cache'}   = Cache::File->new(
   #   cache_root      => '/tmp/GERASCACHE',
   #   default_expires => '3600 sec',
   #);
   $self->{'cache'} = CHI->new( 
      driver => 'Memory', 
      global => 1,
      expires_in => 600,
      );

   $self->{'share'} = IPC::ShareLite->new(
        -key     => 'mqtt',
        -create  => 'yes',
        -destroy => 'no'
    ) or confess $!;

   return $self;
}

#-------------------------------------------------------------------------------
sub error {
#-------------------------------------------------------------------------------
   my $obj   = shift || confess "No Object!";
   my $msg   = shift || return $ERRORS;

   warn $msg;
   $ERRORS = []
      if(not defined $ERRORS);

   push(@$ERRORS, $msg);
   
   return undef;
}

#-------------------------------------------------------------------------------
sub publish {
#-------------------------------------------------------------------------------
   my $obj   = shift || confess "No Object!";
   my $serie = shift || confess "No Serie!";
   my $value = shift || '';

   # Pack in Array
   if(not ref $serie eq 'ARRAY'){
      $serie = [{$serie => $value}];
   }

   my $share = [];

   foreach my $entry (@$serie){
      my($topic, $value) = each %$entry;

      # Save in shared Memory for web process
      push(@$share, {
         topic => $topic,
         when  => time,
         value => $value,
      });

      # ok, ugly solution but it works :)
      my $mosquito = sprintf('/usr/bin/mosquitto_pub -u "" -P "%s" -h %s -t %s -m "%s"', 
         $obj->{apikey}, $obj->{host}, $topic, $value);

      my $erg = `$mosquito; echo \$?`;
      chomp $erg;
      $obj->error("Call failed for topic: $topic with value: $value") 
         if($erg != 0);
   }

   $obj->{share}->lock( LOCK_EX|LOCK_NB );
   $obj->{share}->store(encode_json($share));
   $obj->{share}->unlock();

   return 1;
}

#-------------------------------------------------------------------------------
sub fetchdata {
#-------------------------------------------------------------------------------
   my $obj   = shift || confess "No Object!";

   # get shared Memory for web process
   my $string = $obj->{share}->fetch;

   # remove old data cuz one read are atomar
   # to prevent fetch same data twice time
   if($string){
      $obj->{share}->lock( LOCK_EX|LOCK_NB );
      $obj->{share}->store('');
      $obj->{share}->unlock();
      return decode_json( $string );
   }
   return 0;
}


#-------------------------------------------------------------------------------
sub series {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $only = shift || '';
   
   my $return = [];
   if($only and $only =~ /,/){
      my $erg = $obj->_getJSON('/serieslist');
      foreach my $tag (split(',',$only)){
         foreach my $serie (@$erg){
            push(@$return, $serie)
               if($serie =~ /sensors\/$tag/i);
         }
      }
      return $return
   }
   elsif($only){
      return $obj->_getJSON('/serieslist', $only);
   }
   else {
      return $obj->_getJSON('/serieslist');
   }
}

#-------------------------------------------------------------------------------
sub series_id {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie   =shift || return '';

   my @tokens = split(/\//, $serie);
   return $tokens[1];
}

#-------------------------------------------------------------------------------
sub series_group {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serietag = shift || confess "No Serie";

   my $GroupName = '';
   my $allGroups = $obj->groups();
   foreach my $groupName (sort keys %$allGroups){
      foreach my $groupValue (@{$allGroups->{$groupName}}){
         if($groupValue =~ /\/$serietag\//){
            $GroupName = $groupName;
         }
      }
   }

   return $GroupName;
}

#-------------------------------------------------------------------------------
sub series_unique {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $topic = shift || 0;
   my $full = shift || 0;
   
   my $entrys = {};
   foreach my $serie (@{$obj->series}){
      my @tokens = split(/\//, $serie);
      if($full){
         pop(@tokens);
         $entrys->{join('/', @tokens)} = 1;
      }
      else {
         $entrys->{$tokens[$topic+1]} = 1;
      }

   }

   return [sort keys %$entrys];
}

#-------------------------------------------------------------------------------
sub series_delete {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie   =shift || confess "No Serie to delete!";
   
   $obj->{cache}->clear();
   $obj->_getHTTP('/series'.$serie, undef, 'DELETE');
}

#-------------------------------------------------------------------------------
sub series_add_to_group {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie =shift || confess "No Serie to add to group!";
   my $group =shift || confess "No Group to add to group!";

   ($serie) = $obj->series($serie)
      or return $obj->error("Can't find serie $serie!")
         if(not ref $serie eq 'ARRAY');

   $group = $obj->groups($group)
      or $obj->groups_new($group, []);

   my($groupname, $groupvalues) = each(%$group);
   push(@$groupvalues, @$serie); 
   $groupname = (split('/', $groupname))[-1];
   
   $obj->groups_new($groupname, $groupvalues); 
}

#-------------------------------------------------------------------------------
sub series_remove_from_group {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie =shift || confess "No Serie to delete!";
   my $group =shift || confess "No Serie to delete!";

   my $serieHash;
   my $series = $obj->series($serie)
      or return $obj->error("Can't find serie $serie!");

   map {$serieHash->{$_} = 1} @$series;
   
   ($group) = $obj->groups($group)
      or return $obj->error("Can't find group $group!");

   my($groupname, $groupvalues) = each(%$group);
   $groupname = (split('/', $groupname))[-1];

   my $newGroupValues = [];
   foreach my $groupvalue (@$groupvalues){
      push(@$newGroupValues, $groupvalue) 
         if(not exists $serieHash->{$groupvalue});
   }
   
   $obj->groups_new($groupname, $newGroupValues); 
}

#-------------------------------------------------------------------------------
sub series_move_to_group {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $seriestag =shift || confess "No Serietag to move!";
   my $group =shift || confess "No Serie to move!";

   my ($series) = $obj->series($seriestag)
      or return $obj->error("Can't find serie $seriestag!");
   
   foreach my $serie (@$series){
      # Try to find serie in an old group ..   
      my $sourceGroupName = $obj->series_group($serie);
   
      # Return if group the same
      return if($group eq $obj->group_name($sourceGroupName));
   
      # remove from old group ...
      if($sourceGroupName){
         $obj->series_remove_from_group($serie, $sourceGroupName);
      }
   }

   my ($targetGroup) = $obj->groups($group);
   if(not $targetGroup){
         # .. create new group with series
      $obj->groups_new($group, $series);
   }
   else {
      # ... and add to new group
      $obj->series_add_to_group($series, keys %$targetGroup);
   }      

}

#-------------------------------------------------------------------------------
sub groups {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $only = shift || '';

   my $grouped = {};
   my $return = $obj->_getJSON('/group');
   foreach my $group (keys %$return){
      map { $grouped->{$_} = 1 } @{$return->{$group}}
         if(ref $return->{$group});
   }

   # Add all series to unknown wo group
   $return->{'/group/aaaa/unknown'} = [];
   foreach my $serie (@{$obj->series()}){
      push(@{$return->{'/group/aaaa/unknown'}}, $serie)
         if(not exists $grouped->{$serie});
   }
   # Dont display if all sensors grouped
   delete $return->{'/group/aaaa/unknown'} 
      if(not scalar @{$return->{'/group/aaaa/unknown'}});

   if($only){
      foreach my $group (sort keys %$return){
         return { $group => $return->{$group} }
            if($group =~ /$only$/i);
      }
   }
   else {
      return $return;
   }
}

#-------------------------------------------------------------------------------
sub group_name {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $group   =shift || return '';

   my @tokens = split(/\//, $group);
   return $tokens[-1];
}


#-------------------------------------------------------------------------------
sub groups_new {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $name = shift || confess "No Name!";
   my $list = shift || [];


   my $data = {
      group_id => $name,
      list => $list,
   };
   
   $obj->{cache}->clear();
   $obj->_getJSON('/group', $data, 'POST');
}

#-------------------------------------------------------------------------------
sub groups_delete {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $name = shift || confess "No Name!";
   
   if(my $groups =   $obj->groups($name)){
      my ($todelete) = keys %{$groups}
         or return $obj->error("Can't find group $name for delete!");
   
      $obj->{cache}->clear();
      $obj->_getHTTP($todelete, undef, 'DELETE');
   }
}


#-------------------------------------------------------------------------------
sub shares {
#-------------------------------------------------------------------------------
   my $obj     = shift || confess "No Object!";
   my $type    = shift || '';
   $type = ($type ? 'woshare' : 'share');   
   
   $obj->_getJSON('/'.$type);
}

#-------------------------------------------------------------------------------
sub share_delete {
#-------------------------------------------------------------------------------
   my $obj        = shift || confess "No Object!";
   my $share      = shift || confess "No Share to delete!";
   my $type       = shift || '';
   $type = ($type ? 'woshare' : 'share');   

   $obj->{cache}->clear();
   $obj->_getHTTP('/'.$type.$share, undef, 'DELETE');
}

#-------------------------------------------------------------------------------
sub rollup {
#-------------------------------------------------------------------------------
   my $obj     = shift || confess "No Object!";
   my $serie   =shift || confess "No Serie!";
   my $rollup  =shift || confess "No Rollup ('min','max','avg','sum')!";
   my $interval=shift || confess "No Interval ('s','m','h','d','w','mo','y')!";
   my $start   =shift || 0;
   my $end     =shift || 0;

   my $possibleRollup = ['min','max','avg','sum'];
   my $possibleInterval = ['s','m','h','d','w','mo','y'];

   confess "Rollup $rollup are not correct!"
      if(not grep(/^$rollup$/i, @$possibleRollup));

   my $url = sprintf('/series%s?rollup=%s&interval=%s', $serie, $rollup, $interval);
   $url = sprintf('/series?pattern=%s&rollup=%s&interval=%s', uri_escape($serie), $rollup, $interval)
      if($serie =~ /\+$/);

   $url .= '&start='.$start   if($start);
   $url .= '&end='.$end       if($end);
   $url .= '&start='.(time - 2 * 24 * 3600)
      if(not $start);

   $obj->_getJSON($url);
}


# dum( $geras->timewindow('/sensors/155/power','30s') );# 30sec
# dum( $geras->timewindow('/sensors/155/power','1m') );# 1min
# dum( $geras->timewindow('/sensors/155/power','1h') );# 1hour
# dum( $geras->timewindow('/sensors/155/power',undef,1410338021,1410338081) );# 1min
#-------------------------------------------------------------------------------
sub timewindow {
#-------------------------------------------------------------------------------
   my $obj     =shift || confess "No Object!";
   my $serie   =shift || confess "No Serie!";
   my $zeit    =shift || '';
   my $start   =shift || 0;
   my $end     =shift || 0;
   if($zeit){
      my ($count, $type) = $zeit =~ /^(\d+)([smhdw]+)$/;
      confess "Can't read $zeit with type: $type in timewindow!!" 
         if(not exists $timeWindow->{lc $type});
      $start = time - ($count * $timeWindow->{lc $type});
   }

   my $url = sprintf('/series%s?start=%s', uri_escape($serie), $start);
   $url = sprintf('/series?pattern=%s&start=%s', uri_escape($serie), $start)
      if($serie =~ /\+$/);
   $url .= sprintf('&end=%d', $end) if($end);

   $obj->_getJSON($url);
}

#-------------------------------------------------------------------------------
sub lastvalue {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie=shift || confess "No Serie!";
   
   values %{$obj->_makeHash($obj->_getJSON('/now'.$serie))};
}


#-------------------------------------------------------------------------------
sub _makeHash {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $entrys = shift || {};
   
   my $return = {};
   foreach my $entry (@{$entrys->{e}}){
      $return->{$entry->{t}} = $entry->{v};
   }

   return $return;
}

#-------------------------------------------------------------------------------
sub _getHTTP {
#-------------------------------------------------------------------------------
   my $obj = shift   || confess "No Object!";
   my $url = shift   || confess "No URL!";
   my $only = shift  || '';
   my $type = shift  || 'GET';

   $url = sprintf('http://%s%s', $obj->{host}, $url);
   warn "$type: $url";
   
   my $ua = LWP::UserAgent->new();
   $ua->env_proxy();
   my $req = HTTP::Request->new($type, $url);
   $req->authorization_basic($obj->{apikey}, '');
      
   my $res = $ua->request($req);
   if($res->is_success){
      return $res->content;
   }
   else {
      confess $res->status_line;
   }
}


#-------------------------------------------------------------------------------
sub _getJSON {
#-------------------------------------------------------------------------------
   my $obj = shift   || confess "No Object!";
   my $url = shift   || confess "No URL!";
   my $only = shift  || '';
   my $type = shift  || 'GET';

   $type = uc $type if($type);  

   my $data = encode_json($only) and $only = ''
      if(ref $only);
   
   $url = sprintf('http://%s%s', $obj->{host}, $url);
   my $json;
   
   # Cached results?
   my $cached = $obj->{cache}->get($url);
   if($cached and $type eq 'GET'){
      $json = decode_json($cached);
   }
   else {
      my $ua = LWP::UserAgent->new();
      $ua->env_proxy();
      my $req = HTTP::Request->new($type, $url);
      $req->authorization_basic($obj->{apikey}, '');
      if($data){
          $req->header( 'Content-Type' => 'application/json' );
          $req->content($data);
      }

      
      my $res = $ua->request($req);
      if($res->is_success){
         my $content = $res->content;
         $obj->{cache}->set($url, $content)
            if($type eq 'GET');
         $json = eval{ decode_json($content) } || $json;
      }
      else {
         confess $res->status_line;
      }
   }
   if(ref $json eq 'ARRAY'){
      return [grep(/$only\//i, @$json)];
   }
   elsif(ref $json eq 'HASH'){
      my $return = {};
      foreach my $key (keys %$json){
         $return->{$key} = $json->{$key}
            if(not $only or ($key eq $only or $key =~ /\/$only$/i or $key =~ /$only\//i));
      }
      return $return;
   }
   return $obj->_makeHash($json);
}

#-------------------------------------------------------------------------------
sub clearCache {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $entry = shift || '';
   
   $obj->{cache}->clear();
}


1;