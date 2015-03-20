
# NAME

XHome::Sensor - Module to get an sensor as object oriented

# SYNOPSIS

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

# DESCRIPTION

Package to manage Senors.
# NAME

XHome::Alarm - Module to set alarm level and call alarm,
alarms and types are defined in config file:

    <alarmtype MAIL>
       from 'xambi@foo.de'
       to 'xpix@bar.de'
    </alarmtype>



# SYNOPSIS

    my $sensorobj = XHome::Alarm->new({
       topic => $event->{topic},
    });

    $sensorobj->check(); # check if alaram happend

     $sensorobj->alarm(); # call alarm
    



# DESCRIPTION

Package to manage Senors.

# METHODS

    $sensorobj->lastalarm;   # get time of last alarm
    $sensorobj->MAIL($msg);  # send alarm mail 
    $sensorobj->SMS($msg);   # send alarm sms
    $sensorobj->range;       # get alarm range
    $sensorobj->sensor;      # get sensor object
