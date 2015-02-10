xambiserver for XAmbi Network
-----------
By Frank Herrmann (xpixer@gmail.com)

![Screenshot from Webinterface](https://github.com/xpix/xambiserver/blob/master/public/images/capture.gif?raw=true)

##Synopsis
The xambiserver project are a couple of tools to install a MQTT Network and Webinterface to display the saved Sensor-Data from a MQTT Broker. This tools are written in Perl and need some additional Modules, they have to install on youre Linux System. You can choose your infrastructure to install follow tools:

- Raspberry: Webinterface and [Gateway](https://github.com/xpix/XAmbi) for [XAmbi Nodes](https://github.com/xpix/XAmbi/tree/master/Xambi_kids)
- NAS for MQTT Broker and Subscribe tool to save all Data in sqlite-db file.


##Install
`aptitude install libmojolicious-perl libjson-xs-perl`

##Start Webinterface server
`cd xambiserver`

`morbo -l http://*:3080 server_local.pl`

`firefox http://localhost:3080`


##Configuration
Please read the [Readme.md](https://github.com/xpix/xambiserver/tree/master/cfg) in cfg directory.

##more Informations
- [Subscribe](https://github.com/xpix/xambiserver/tree/master/bin) a MQTT Broker and install an json-api-server call on same or other machine.
- [XAmbi Sensor  and Alarm Modules](https://github.com/xpix/xambiserver/tree/master/XHome)
- [XAmbi API for API json server](https://github.com/xpix/xambiserver/tree/master/XAmbi)

