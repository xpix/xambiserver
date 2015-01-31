use Mojolicious::Lite;
use Mojo::JSON qw(decode_json encode_json);
use DBI;

$ENV{CONFIGFILE} = 'cfg/users.cfg';
use Config::General;
my $conf = Config::General->new($ENV{CONFIGFILE});
my %cfg = $conf->getall;

# Here you can configure any of your server settings right 
# within the app. 
app->config(hypnotoad => {listen => ['http://*:3080']});

# Global handle for db connections
my $dbh = "";
my $database   = "db/xambimqtt.db";
my $topicstable= "mqtt";

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
        return $dbh;
    }
};

# Disconnect db connection
helper db_disconnect => sub {
    my $self = shift;
    $self->db->disconnect;
    $dbh = "";  
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
    
    my $SQL = "select username from t_api_access where token = '$token' and active = 1";
    my $cursor = $self->db->prepare($SQL);
    $cursor->execute;
    my @username = $cursor->fetchrow;
    $cursor->finish;
    
    if($username[0]){
        return 1;
    }else{
        $self->render(text => 'Access denied');
        $self->db_disconnect;
        return;
    }
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

    my $SQL = "select * from $dbtable where id = '$id'";
    my $cursor = $self->db->prepare($SQL);
    $cursor->execute;
    my @data = $cursor->fetchrow;
    $cursor->finish;
    $self->db_disconnect;
    
    return $self->render(json => \@data);
};


# Here is a route that takes in serialized JSON data,
# parses it and loads it into a database.  In this 
# simple example, the incoming JSON contains just 
# a few fields (id, data).
post '/group/add' => sub {
    my $self  = shift;
    my $json_data = $self->param('json');
    my $date = $self->date;
    
    my $json = Mojo::JSON->new;
    my $hash = $json->decode($json_data);
    my $err  = $json->error;
    
    # JSON parse error
    if($err){
        return $self->render(json => {result => "0", message => "$err"});
    }
    
    my $data = $hash->{'data'};
    my $id = $hash->{'id'};

    # Make sure we escape the incoming data...
    $data = $self->db->quote($data);
    $id = $self->db->quote($id);

    my $SQL = "insert into $dbtable (topic, data) values ('$id',$data)";
    my $cursor = $self->db->prepare($SQL);
    $cursor->execute;
    my $new_id = $cursor->{mysql_insertid};
    $cursor->finish;
    $self->db_disconnect;
    
    if($new_id){
        return $self->render(json => {result => "1", message => "OK"});
    }else{
        return $self->render(json => {result => "0", message => "Insert Failure"});
    }

};

# Start the app
app->start;