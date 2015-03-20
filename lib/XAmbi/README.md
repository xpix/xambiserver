# NAME


XAmbi::Api - Module to get a all data from supported JSON-API found at https://github.com/xpix/xambiserver/blob/master/bin/api.pl


# SYNOPSIS


    use XAmbi::Api;
    my $xambi = XAmbi::Api->new({
       host   => '127.0.0.1',
       port   => '3080',
       noproxy=> 1,
    });
    

    $xambi->clearCache();
    $xambi->series();
 

# DESCRIPTION


Package to manage API Calls via http json to xambi api.


# Methods


## `error( $msg )`


Returns or registered an Error if $msg defined.


## `publish( $serie, $value )`


Send data to mqtt broker via publish and save to a shared memory for access for other processes.


## `fetchdata()`


Get Data from shared memory for other processes.


## `series( $only )`


Get all Series as list or only series for one id.


## `series\_id( '/foo/200/value' )`


Return the id (200) from a topic.


## `series\_group( $id )`


Get Group entry for serie with $id (i.e.: 200).


## `series\_unique( $topic, $full )`


Get a list with Series but in unique form. The entrys can be full qualified (/foo/200/power)


## `series\_delete( $topic)`


Delete Serie with all Data.


## `series\_add\_to\_group( $serie, $group )`


Add Serie of topics to a named group.


    $xambi->series_add_to_group(200, 'Garden')
  

## `series\_remove\_from\_group( $serie )`


Remove Serie of topics from groups.


    $xambi->series_remove_from_group(200)
  

## `series\_move\_to\_group( $serie, $group )`


Move Serie of topics to named group.


    $xambi->series_remove_from_group(200, 'Garden')
  

## `groups( $group )`


List groups or only entrys they are match to $group.


    $xambi->groups('Garden')
  

## `groups\_new( $group )`


Add new named group to groups.


    $xambi->groups_new('Garden')
  

## `groups\_delete( $group )`


Remove named group from groups and put series to "Unknown" group.


    $xambi->groups_delete('Garden')
  

## `rollup( $serie, $rollup, $interval, $start, $end )`


Return listed data from serie in a specific timeinterval in average, min, max value.
$average can be 'avg', 'min', 'max', 'sum'
$interval can be 'Xm' for minute, 'Xh' for hour, 'Xd' for day, 'Xw' for week.
$start in seconds since epoch
$end in seconds since epoch


    my $list = $xambi->rollup('/sensors/200', 'avg', '1h')
  

## `lastvalue( $topic )`


Remove named group from groups and put series to "Unknown" group.


    $xambi->lastvalue('/foo/200/value')
  

## `clearCache( $entry )`


Clear cache complete or only for $entry.


    $xambi->clearCache()
  
