package Geras::Api;

use warnings;
use strict;

use LWP::UserAgent;
use JSON::XS;
use Cache::File;
use IPC::ShareLite qw( :lock );

use Data::Dumper;
sub dum { printf "DEBUG: %s\n", Dumper(@_); };

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
  die $list->error() if($list->error());

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
   $self->{'apikey'}  = delete $args->{'apikey'} || die "No Apikey in new!";
   $self->{'host'}    = delete $args->{'host'}   || 'geras.1248.io';

   $self->{'cache'}   = Cache::File->new( 
      cache_root => '/tmp/GERASCACHE'
   );

   $self->{'share'} = IPC::ShareLite->new(
        -key     => 'mqtt',
        -create  => 'yes',
        -destroy => 'no'
    ) or die $!;

   return $self;
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

#-------------------------------------------------------------------------------
sub publish {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";
   my $serie = shift || die "No Serie!";
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
      my $erg = `/usr/bin/mosquitto_pub -u "" -P "$obj->{apikey}" -h $obj->{host} -t $topic -m "$value"; echo \$?`;
      chomp $erg;
      warn "Call failed for topic: $topic with value: $value" if($erg != 0);
   }

   $obj->{share}->lock( LOCK_EX|LOCK_NB );
   $obj->{share}->store(encode_json($share));
   $obj->{share}->unlock();

   return 1;
}

#-------------------------------------------------------------------------------
sub fetchdata {
#-------------------------------------------------------------------------------
   my $obj   = shift || die "No Object!";

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
   my $obj = shift || die "No Object!";
   my $only = shift || '';
   
   $obj->_getJSON('/serieslist', $only);
}

#-------------------------------------------------------------------------------
sub series_group {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
   my $serietag = shift || die "No Serie";

   my $GroupName = '';
   my $allGroups = $obj->groups();
   foreach my $groupName (sort keys %$allGroups){
      foreach my $groupValue (@{$allGroups->{$groupName}}){
         if($groupValue =~ /\/$serietag\//){
            $GroupName = $groupName;
         }
      }
   }

   return $GroupName || 'unknowngroup';
}

#-------------------------------------------------------------------------------
sub series_unique {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
   my $topic = shift || 0;
   
   my $entrys = {};
   foreach my $serie (@{$obj->series}){
      my @tokens = split(/\//, $serie);
      $entrys->{$tokens[$topic+1]} = 1;
   }

   return [sort keys %$entrys];
}

#-------------------------------------------------------------------------------
sub series_delete {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
   my $serie   =shift || die "No Serie to delete!";
   
   $obj->{cache}->clear();
   $obj->_getHTTP('/series'.$serie, undef, 'DELETE');
}

#-------------------------------------------------------------------------------
sub series_add_to_group {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
   my $serie =shift || die "No Serie to delete!";
   my $group =shift || die "No Serie to delete!";

   ($serie) = $obj->series($serie)
      or return $obj->error("Can't find serie $serie!");

   $group = $obj->groups($group)
      or return $obj->error("Can't find group $group!");

dum($group);

   my($groupname, $groupvalues) = each(%$group);
   push(@$groupvalues, @$serie); 
   $groupname = (split('/', $groupname))[-1];
   
   $obj->groups_new($groupname, $groupvalues); 
}

#-------------------------------------------------------------------------------
sub series_remove_from_group {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
   my $serie =shift || die "No Serie to delete!";
   my $group =shift || die "No Serie to delete!";

   my $serieHash;
   ($serie) = $obj->series($serie)
      or return $obj->error("Can't find serie $serie!");
   map {$serieHash->{$_} = 1} @$serie;
   
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
   my $obj = shift || die "No Object!";
   my $serietag =shift || die "No Serietag to delete!";
   my $group =shift || die "No Serie to delete!";

   my ($serie) = $obj->series($serietag)
      or return $obj->error("Can't find serie $serietag!");

   ($group) = $obj->groups($group)
      or return $obj->error("Can't find group $group!");

   # Try to find serie in an old group ..   
   my $sourceGroupName = $obj->series_group($serietag);

   # remove from old group ...
   if($sourceGroupName){
      $obj->series_remove_from_group($serietag, $sourceGroupName);
   }
   # ... and add to new group
   $obj->series_add_to_group($serietag, $group);
}

#-------------------------------------------------------------------------------
sub groups {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
   my $only = shift || '';
   
   $obj->_getJSON('/group', $only);
}

#-------------------------------------------------------------------------------
sub groups_new {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
   my $name = shift || die "No Name!";
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
   my $obj = shift || die "No Object!";
   my $name = shift || die "No Name!";
   
   my ($todelete) = keys %{$obj->groups($name)}
      or return $obj->error("Can't find group $name for delete!");

   $obj->{cache}->clear();
   $obj->_getHTTP($todelete, undef, 'DELETE');
}


#-------------------------------------------------------------------------------
sub shares {
#-------------------------------------------------------------------------------
   my $obj     = shift || die "No Object!";
   my $type    = shift || '';
   $type = ($type ? 'woshare' : 'share');   
   
   $obj->_getJSON('/'.$type);
}

#-------------------------------------------------------------------------------
sub share_delete {
#-------------------------------------------------------------------------------
   my $obj        = shift || die "No Object!";
   my $share      = shift || die "No Share to delete!";
   my $type       = shift || '';
   $type = ($type ? 'woshare' : 'share');   

   $obj->{cache}->clear();
   $obj->_getHTTP('/'.$type.$share, undef, 'DELETE');
}

#-------------------------------------------------------------------------------
sub rollup {
#-------------------------------------------------------------------------------
   my $obj     = shift || die "No Object!";
   my $serie   =shift || die "No Serie!";
   my $rollup  =shift || die "No Rollup ('min','max','avg','sum')!";
   my $interval=shift || die "No Interval ('s','m','h','d','w','mo','y')!";

   my $possibleRollup = ['min','max','avg','sum'];
   my $possibleInterval = ['s','m','h','d','w','mo','y'];

   die "Rollup $rollup are not correct!"
      if(not grep(/^$rollup$/i, @$possibleRollup));

   my $url = sprintf('/series%s?rollup=%s&interval=%s', $serie, $rollup, $interval);

   $obj->_getJSON($url);
}

#-------------------------------------------------------------------------------
sub timewindow {
#-------------------------------------------------------------------------------
   my $obj     =shift || die "No Object!";
   my $serie   =shift || die "No Serie!";
   my $start   =shift || die "No Starttime in seconds since epoch";
   my $end     =shift || die "No Endtime in seconds since epoch";

   my $url = sprintf('/series%s?start=%s&end=%s', $serie, $start, $end);
   
   $obj->_getJSON($url);
}

#-------------------------------------------------------------------------------
sub lastvalue {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
   my $serie=shift || die "No Serie!";
   my $only = shift || '';
   
   $obj->_getJSON('/now/'.$serie);
}


#-------------------------------------------------------------------------------
sub _makeHash {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
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
   my $obj = shift   || die "No Object!";
   my $url = shift   || die "No URL!";
   my $only = shift  || '';
   my $type = shift  || 'GET';

   $url = sprintf('http://%s%s', $obj->{host}, $url);
   warn "$type: $url";
   
   my $ua = LWP::UserAgent->new();
   my $req = HTTP::Request->new($type, $url);
   $req->authorization_basic($obj->{apikey}, '');
      
   my $res = $ua->request($req);
   if($res->is_success){
      return $res->content;
   }
   else {
      die $res->status_line;
   }
}


#-------------------------------------------------------------------------------
sub _getJSON {
#-------------------------------------------------------------------------------
   my $obj = shift   || die "No Object!";
   my $url = shift   || die "No URL!";
   my $only = shift  || '';
   my $type = shift  || 'GET';

   $type = uc $type if($type);  

   my $data = encode_json($only) and $only = ''
      if(ref $only);
   
   $url = sprintf('http://%s%s', $obj->{host}, $url);
   warn "$type: $url";
   my $json;
   
   # Cached results?
   my $cached = $obj->{cache}->get($url);
   if($cached and $type eq 'GET'){
      $json = decode_json($cached);
   }
   else {
      my $ua = LWP::UserAgent->new();
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
         die $res->status_line;
      }
   }

   if(ref $json eq 'ARRAY'){
      return [grep(/$only\//i, @$json)];
   }
   elsif(ref $json eq 'HASH'){
      my $return = {};
      foreach my $key (keys %$json){
         $return->{$key} = $json->{$key}
            if($key eq $only or $key =~ /\/$only$/i or $key =~ /$only\//i);
      }
      return $return;
   }
   return $obj->_makeHash($json);
}

#-------------------------------------------------------------------------------
sub clearCache {
#-------------------------------------------------------------------------------
   my $obj = shift || die "No Object!";
   my $entry = shift || '';
   
   $obj->{cache}->clear();
}


1;