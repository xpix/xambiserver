use Mojolicious::Lite;
use JSON::XS;
use DBI;
use XHome::Sensor;
use Data::Dumper;
sub dum { warn Dumper(@_) };


$ENV{CONFIGFILE} = 'cfg/sensors.cfg';

# Global handle for db connections
my $created = "";
my $dbh = "";
my $database   = "db/xambimqtt.db";
my $topicstable= "mqtt";
my $groupstable= "mqtt_groups";

my $timeWindow = {
   s => 1, # second
   m => 60, # minute
   h => 3600, # hour
   d => 24 * 3600, # day
   w => 7 * 24 * 3600, # week
};


# Helpers are like methods for the instantiated process 
# that is created when someone invoke our API.  I've
# created a few helpers below:

# Create db connection if needed
helper db => sub {
    if($dbh){
        return $dbh;
    }else{
        $dbh = DBI->connect("DBI:SQLite:dbname=$database", "", "", {'RaiseError' => 1})
                     or die $DBI::errstr;
        create_group_table() 
            if(not $created);
        return $dbh;
    }
};

# Disconnect db connection
helper db_disconnect => sub {
    my $self = shift;
    $self->db->disconnect;
    $dbh = "";  
};

helper sql => sub{
    my $self = shift;
    my $SQL  = shift || die "No Sql Statement";
    my $cursor = $self->db->prepare($SQL);
    $cursor->execute;
    my @data = $cursor->fetchall_arrayref;
    $cursor->finish;
    $self->db_disconnect;
    return \@data;
};

helper lastInsertId => sub {
    my $self = shift;
    my $data = $self->sql("SELECT last_insert_rowid()");
    return shift @$data;
};

helper groups => sub {
    my $self = shift;
    my $name = shift || '';
    my $type = shift || '';
    my $where = ($name ? "WHERE GROUPNAME = '$name'" : "");


    my $data = $self->sql("SELECT GROUPNAME, TOPICNAME FROM $groupstable $where");
    if(lc $type eq 'extended'){
      my $return = {};
      foreach my $entry (@{$data->[0]}){
         push(@{$return->{$entry->[0]}}, $entry->[1]);
      }
      $data = $return;
    }

    return $data;
};

helper topics => sub {
    my $self = shift;
    my $name = shift || '';
    my $type = shift || '';

    my $distinct  = (lc $type eq 'distinct' ? 'DISTINCT' : '');
    my $now       = (lc $type eq 'now'      ? 'ORDER BY ID DESC LIMIT 1' : '');
    my $where     = ($name ? "WHERE TOPIC LIKE '$name%'" : "");
    my $field     = ($distinct ? 'TOPIC' : '*');

    my $data = $self->sql("SELECT $distinct $field FROM $topicstable $where $now");
    return $data;
};

helper preparedata => sub{
    my $self = shift;
    my $data = shift || [];

   my $timegrouped = {};
   map {
      # Group in 10 sec steps
      my @trible = split(//, $_->[1]);
      pop @trible;
      my $mark = join('', @trible);
      push(@{$timegrouped->{$mark}}, $_);
   } @{$data->[0]};

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

         $self->{$topic} = XHome::Sensor->new({topic => $topic})
            unless(exists $self->{$topic});
         my $sensor = $self->{$topic};
         $sdata->{$name} = sprintf("%.3f", $value / ($sensor->display->{divider} || 1));

         if(my $range = $sensor->{alarmobj}->range()){
            $sdata->{'Alarm'} = $range->[0];
         }
      }
      push(@$return, $sdata);   
   };

   $return;

};

helper render_jsonp => sub {
   my $self = shift;
   my %render = @_;

   if(defined $render{'json'} and my $cb = $self->param('callback')){
      $self->render(text => "$cb (".
         encode_json($render{'json'}{'result'})
         . " )"
      );
   }
   else {
      $self->render(%render);
   }
};


# Under is a Mojolicious syntax tag for eliminating repetitive coding.
# If you have something that you want run every time an API call 
# is made, regardless of which API call, then put it in the "under"
# section here.  This code will always be executed before any API 
# routes are processed.  Returning a 1 will allow the request 
# to continue, anything else will stop the request.

# Always check auth token!  Here we validate that every API request 
# has a valid token
under sub {
    my $self  = shift;
    my $token   = $self->param('token');

    return 1; #XXX token support
};

# Routes:  Here is where you define your API routes, or paths.
# You can define as many as you like to support all your API 
# functionality. "get" says that this API route will only 
# accept GET requests.  You can use "post" or "any" as well.

# Route to grab a record using an ID that is passed in from a database
# and return as JSON.
# Example URL request:  /data/298
get '/data/:id' => sub {
    my $self  = shift;
    my $id  = $self->stash('id');

    my @data = $self->sql("select * from $topicstable where id = '$id'");
    
    return $self->render_jsonp(json => \@data);
};

# http://localhost:3080/topic/list?path=/sensors/112
# http://localhost:3080/topic/list?type=distinct&path=/sensors
# http://localhost:3080/topic/list?type=distinct&path=/sensors/315
# http://localhost:3080/topic/list?type=distinct&path=/sensors/315/power
get '/topic/list' => sub {
    my $self  = shift;
    my $type   = $self->param('type');
    my $path   = $self->param('path');

    return $self->render_jsonp(json => {result => $self->topics($path, $type), message => "OK",debug => $type});
};

# http://localhost:3080/topic/now?path=/sensors/112/power
get '/topic/now' => sub {
    my $self  = shift;
    my $type   = 'now';
    my $path   = $self->param('path');

    return $self->render_jsonp(json => {result => $self->topics($path, $type), message => "OK",debug => $type});
};

# http://localhost:3080/topic/rollup/avg/1d?path=/sensors/112/power&start=1423048000&end=1423049000
# http://localhost:3080/topic/rollup/min/1d?path=/sensors/112/power&start=1423048000
# http://localhost:3080/topic/rollup/min/1d?path=/sensors/112/power&start=-300 # (last 5 min)
# http://localhost:3080/topic/rollup/max/1d?path=/sensors/112/power
get '/topic/rollup/:rollup/:interval' => sub {
    my $self  = shift;
    my $rollup  = lc $self->stash('rollup');
    my $interval= lc $self->stash('interval');
    my ($cnt, $inter) = $interval =~ /(\d+)(\S+)/; # 2d => 1,d
    my $seconds = ($cnt * $timeWindow->{$inter});
  
    # Special Parameters
    my $path      = $self->param('path');
    my $start     = $self->param('start');
    my $end       = $self->param('end');
    my $prepare   = $self->param('prepare');

    # Support negative values for last x seconds
    $start = time + $start if($start < 0);

    my $between = '';
    $between .= ($start ? "AND timestamp > $start " : "");
    $between .= ($end   ? "AND timestamp < $end " : "");

    # get all series and mix data
    my $series = $self->topics($path, 'distinct');
    my $return = [[]];
    foreach my $serie (@{$series->[0]}){
       my $sql = "
         select 
            datetime((strftime('%s', datetime(timestamp,'unixepoch')) / $seconds) * $seconds, 'unixepoch') interval, 
            timestamp,
            topic,
            $rollup(value) val
         from 
            mqtt 
         where 
            topic = '$serie->[0]' 
            $between
         group by interval 
         order by interval;
      ";
      my $erg = $self->sql($sql);
      push(@{$return->[0]}, @{$erg->[0]});
    }

    $return = $self->preparedata($return)
      if($prepare);

    return $self->render_jsonp(json => {result => $return, message => "OK"});
};

# http://localhost:3080/411/addtogroup/Garten
get '/:topic/addtogroup/:group' => sub {
   my $self  = shift;
   my $topic  = $self->stash('topic');
   my $group  = $self->stash('group');
   $topic = "/sensors/$topic";
   my $topics = $self->topics($topic, 'distinct');
   my $erg    = $self->sql("DELETE FROM $groupstable WHERE TOPICNAME LIKE '$topic%'");
   if(lc $group ne 'unknown'){
      foreach my $topic (@{$topics->[0]}){
         my $erg    = $self->sql("REPLACE INTO $groupstable (GROUPNAME, TOPICNAME) VALUES ('$group','$topic->[0]')");
      }
   }
   return $self->render_jsonp(json => {result => 1, message => "Topic with id $topic added to group $group"});
};

# http://localhost:3080/group/list
# http://localhost:3080/group/list?type=extended
get '/group/list' => sub {
    my $self  = shift;
    my $type  = $self->param('type') || '';

    return $self->render_jsonp(json => {result => $self->groups('', $type), message => "OK"});
};

# http://localhost:3080/group/delete/Garten
get '/group/delete/:name' => sub {
    my $self  = shift;
    my $name  = $self->stash('name');

    my $data = $self->sql("DELETE FROM $groupstable WHERE GROUPNAME = '$name'");
    return $self->render_jsonp(json => {result => $data, message => "OK"});
};

# http://localhost:3080/group/add/Garten
get '/group/add/:name' => sub {
    my $self  = shift;
    my $name  = $self->stash('name');

    if($self->groups($name)->[0][0]){
      return $self->render_jsonp(json => {result => "0", message => "Table $name exists!", debug => $self->groups($name)});
    }

    my $erg    = $self->sql("insert into $groupstable (GROUPNAME, TOPICNAME) values ('$name','')");
    my $new_id = $self->lastInsertId;
    
    if($new_id){
        return $self->render_jsonp(json => {result => "1", message => "OK"});
    }else{
        return $self->render_jsonp(json => {result => "0", message => "Insert Failure"});
    }
};

# Start the app
app->start;

sub create_group_table {
   ### create table if not exists
   my $stmt = "
      CREATE TABLE $groupstable (
         ID INTEGER PRIMARY KEY AUTOINCREMENT,
         GROUPNAME          TEXT    NOT NULL,
         TOPICNAME          TEXT    NOT NULL
      );
      CREATE INDEX groupsindex ON $groupstable (GROUPNAME, TOPICNAME);
   ";
   $created = 1;
   return eval{ $dbh->do($stmt) };
}
