package XAmbi::Api;

use warnings;
use strict;

use Carp;
use LWP::UserAgent;
use JSON::XS;
use URI::Escape;
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

XAmbi::Api - Module to get a all data from supported JSON-API found at https://github.com/xpix/xambiserver/blob/master/bin/api.pl

=head1 SYNOPSIS

   use XAmbi::Api;
   my $xambi = XAmbi::Api->new({
      host   => '127.0.0.1',
      port   => '3080',
      noproxy=> 1,
   });
   
   $xambi->clearCache();
   $xambi->series();

=head1 DESCRIPTION

Package to manage API Calls via http json to xambi api.

=cut

#-------------------------------------------------------------------------------
sub new {
#-------------------------------------------------------------------------------
   my $class = shift;
   my $args  = shift;
   my $self  = { };

   bless($self, $class);

   # API Data
   $self->{'host'}    = delete $args->{'host'}   || '127.0.0.1';
   $self->{'port'}    = delete $args->{'host'}   || 3080;
   $self->{'noproxy'} = delete $args->{'noproxy'}|| 0;

   return $self;
}

=pod

=head1 Methods

=head2 C<error( $msg )>

Returns or registered an Error if $msg defined.

=cut
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

=pod

=head2 C<publish( $serie, $value )>

Send data to mqtt broker via publish and save to a shared memory for access for other processes.

=cut
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
      my $mosquito = sprintf('/usr/bin/mosquitto_pub -h %s -t %s -m "%s" -q 1', 
         $obj->{host}, $topic, $value);
      my $erg = `$mosquito; echo \$?`;
      chomp $erg;
      $obj->error("Call failed for topic: $topic with value: $value") 
         if($erg != 0);
   }

   return 1;
}

=pod

=head2 C<series( $only )>

Get all Series as list or only series for one id.

=cut
#-------------------------------------------------------------------------------
sub series {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $only = shift || '';
   
   my $return = [];
   if($only and $only =~ /,/){
      my $erg = $obj->_getJSON('/topic/list?type=distinct');
      foreach my $tag (split(',',$only)){
         foreach my $serie (@$erg){
            push(@$return, $serie)
               if($serie =~ /sensors\/$tag/i);
         }
      }
      return $return
   }
   elsif($only){
      return $obj->_getJSON('/topic/list?type=distinct', $only);
   }
   else {
      return $obj->_getJSON('/topic/list?type=distinct');
   }
}

=pod

=head2 C<series_id( '/foo/200/value' )>

Return the id (200) from a topic.

=cut
#-------------------------------------------------------------------------------
sub series_id {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie   =shift || return '';

   my @tokens = split(/\//, $serie);
   return $tokens[1];
}

=pod

=head2 C<series_group( $id )>

Get Group entry for serie with $id (i.e.: 200).

=cut
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

=pod

=head2 C<series_unique( $topic, $full )>

Get a list with Series but in unique form. The entrys can be full qualified (/foo/200/power)

=cut
#-------------------------------------------------------------------------------
sub series_unique {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $topic = shift || 0;
   my $full = shift || 0;
   
   my $entrys = {};
   my $series = $obj->series();
   foreach my $serie (@$series){
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

=pod

=head2 C<series_delete( $topic)>

Delete Serie with all Data.

=cut
#-------------------------------------------------------------------------------
sub series_delete {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie   =shift || confess "No Serie to delete!";
   
   $obj->_getHTTP('/series'.$serie, undef, 'DELETE');
}

=pod

=head2 C<series_add_to_group( $serie, $group )>

Add Serie of topics to a named group.

  $xambi->series_add_to_group(200, 'Garden')

=cut
#-------------------------------------------------------------------------------
sub series_add_to_group {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie =shift || confess "No Serie to add to group!";
   my $group =shift || confess "No Group to add to group!";

   my $test = $obj->series($serie)
      or return $obj->error("Can't find serie $serie!");

   $obj->_getJSON("/$serie/addtogroup/$group", undef, undef, 'noextract');
}

=pod

=head2 C<series_remove_from_group( $serie )>

Remove Serie of topics from groups.

  $xambi->series_remove_from_group(200)

=cut
#-------------------------------------------------------------------------------
sub series_remove_from_group {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie =shift || confess "No Serie to delete!";

   $obj->_getJSON("/$serie/addtogroup/Unknown", undef, undef, 'noextract');
}

=pod

=head2 C<series_move_to_group( $serie, $group )>

Move Serie of topics to named group.

  $xambi->series_remove_from_group(200, 'Garden')

=cut
#-------------------------------------------------------------------------------
sub series_move_to_group {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $seriestag =shift || confess "No Serietag to move!";
   my $group =shift || confess "No Serie to move!";

   # ... and add to group
   $obj->series_add_to_group($seriestag, $group);
}

=pod

=head2 C<groups( $group )>

List groups or only entrys they are match to $group.

  $xambi->groups('Garden')

=cut
#-------------------------------------------------------------------------------
sub groups {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $only = shift || '';

   my $grouped = {};
   my $return  = {};
   my $data = $obj->_getJSON('/group/list', undef, undef, 'noextract');

   foreach my $list (@$data){
      my($grp, $topic) = @$list;
      $grouped->{$topic} = $grp if($topic);
      push(@{$return->{$grp}}, $topic);
   }
   # Add all series to unknown wo group
   foreach my $serie (@{$obj->series()}){
      push(@{$return->{'Unknown'}}, $serie)
         if(not exists $grouped->{$serie});
   }

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

=pod

=head2 C<groups_new( $group )>

Add new named group to groups.

  $xambi->groups_new('Garden')

=cut
#-------------------------------------------------------------------------------
sub groups_new {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $group   =shift || return '';

   my $data = $obj->_getJSON("/group/add/$group", undef, undef, 'noextract');
}


=pod

=head2 C<groups_delete( $group )>

Remove named group from groups and put series to "Unknown" group.

  $xambi->groups_delete('Garden')

=cut
#-------------------------------------------------------------------------------
sub groups_delete {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $name = shift || confess "No Name!";
   
   my $data = $obj->_getJSON("/group/delete/$name", undef, undef, 'noextract');

   return 1;
}

=pod

=head2 C<rollup( $serie, $rollup, $interval, $start, $end )>

Return listed data from serie in a specific timeinterval in average, min, max value.
$average can be 'avg', 'min', 'max', 'sum'
$interval can be 'Xm' for minute, 'Xh' for hour, 'Xd' for day, 'Xw' for week.
$start in seconds since epoch
$end in seconds since epoch

  my $list = $xambi->rollup('/sensors/200', 'avg', '1h')

=cut
#-------------------------------------------------------------------------------
sub rollup {
#-------------------------------------------------------------------------------
   my $obj     =shift || confess "No Object!";
   my $serie   =shift || confess "No Serie!";
   my $rollup  =shift || confess "No Rollup ('min','max','avg','sum')!";
   my $interval=shift || confess "No Interval ('s','m','h','d','w','mo','y')!";
   my $start   =shift || 0;
   my $end     =shift || 0;

   my $possibleRollup = ['min','max','avg','sum'];
   my $possibleInterval = ['s','m','h','d','w','mo','y'];

   confess "Rollup $rollup are not correct!"
      if(not grep(/^$rollup$/i, @$possibleRollup));

   my $url = sprintf('/topic/rollup/%s/%s?path=%s', $rollup, $interval, uri_escape($serie));

   $url .= '&start='.$start   if($start);
   $url .= '&end='.$end       if($end);
   $url .= '&start='.(time - 2 * 24 * 3600)
      if(not $start);

   return $obj->_getJSON($url,undef,undef,'noextract');
}

=pod

=head2 C<lastvalue( $topic )>

Remove named group from groups and put series to "Unknown" group.

  $xambi->lastvalue('/foo/200/value')

=cut
#-------------------------------------------------------------------------------
sub lastvalue {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $serie=shift || confess "No Serie!";
   
   $obj->_getJSON('/topic/now?path='.$serie)->[-1];
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
   my $obj        = shift  || confess "No Object!";
   my $url        = shift  || confess "No URL!";
   my $only       = shift  || '';
   my $type       = shift  || 'GET';
   my $noextract  = shift  || 0;

   $type = uc $type if($type);  

   my $data = encode_json($only) and $only = ''
      if(ref $only);
   
   $url = sprintf('http://%s:%d%s', $obj->{host}, $obj->{port}, $url);
   
   my $ua = LWP::UserAgent->new();
   $ua->env_proxy() if(not $obj->{noproxy});
   my $req = HTTP::Request->new($type, $url);
   #$req->authorization_basic($obj->{apikey}, '');
   if($data){
       $req->header( 'Content-Type' => 'application/json' );
       $req->content($data);
   }

   
   my $json;
   my $res = $ua->request($req);
   if($res->is_success){
      my $content = $res->content;
      if($noextract){
         $json = eval{ decode_json($content)->{result}->[0] };
      }
      else {
         $json = $obj->extract( eval{ decode_json($content) } );
      }
   }
   else {
      warn $res->status_line;
      return [];
   }

   if(ref $json eq 'ARRAY'){
      return [grep(/$only\//i, @$json)] if($only);
      return $json;
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
# Extract data from DBI Array or HASH in result entry
sub extract {
#-------------------------------------------------------------------------------
   my $obj = shift || confess "No Object!";
   my $data = shift || '';

   my $return=[];
   if($data->{result} and my @d = @{$data->{result}->[0]}){
      foreach my $entry (@d){
         push(@$return, @$entry);
      }
   }
   return $return;   
}


1;