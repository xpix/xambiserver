xambi sensor lib
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

## `read only named probertys`

Lots of methods to return probertys.

    $sensorobj->display(); # Confighash to display this topic
    $sensorobj->divider(); # Divider for raw value
    $sensorobj->name();    # Name for this value in sensor
    $sensorobj->cfg();     # complete Confighashfor all Sensors
    $sensorobj->config();  # Confighash for for this sensor type
    $sensorobj->idx();     # gets Value index or power
    $sensorobj->info();    # get a hash with complete info's about this sensor
    $sensorobj->type();    # return the type of this sensor value
    $sensorobj->topic($t); # set topic
    $sensorobj->value($v); # set or get Value
    $sensorobj->now();     # get now value
    $sensorobj->last();    # get last Value
    $sensorobj->when();    # last change of this sensor value in unixtime
    $sensorobj->id();      # get or set id from topic
    $sensorobj->valueid(); # get or set valueid
    $sensorobj->geras();   # get or set xambi object
    $sensorobj->group();   # get group from sensor object
