xambiserver for XAmbi Network
-----------
By Frank Herrmann (xpixer@gmail.com)

![Screenshot from Webinterface](https://github.com/xpix/xambiserver/blob/master/public/images/capture.gif?raw=true)

##Synopsis
The xambiserver project are a couple of tools to install a MQTT Network and Webinterface to display the saved Sensor-Data from a MQTT Broker. This tools are written in Perl and need some additional Modules, they have to install on youre Linux System. You can choose your infrastructure to install follow tools:

- Raspberry: Webinterface and [Gateway](https://github.com/xpix/XAmbi) for [XAmbi Nodes](https://github.com/xpix/XAmbi/tree/master/Xambi_kids)
- NAS for MQTT Broker and Subscribe tool to save all Data in sqlite-db file.

##Start serial
Start command to subscribe the serial channel from jeenode and send data to a mqtt broker.

`screen -s serial ./serial.pl /dev/ttyUSB0`

##Start MQTT Subscribe
Start command to subscribe all topics at MQTT Server. All data will save to a sqlite Database. 

`screen -s subscribe ./bin/mqtt_subscribe.pl localhost 1883`

##Start API JSON Server
The XAmbi-API will connect to a sqlite DB and return all Data as a JSON API Webserver on a specific port.

`screen -S api morbo -l http://*:3080 bin/api.pl`

##Start Webinterface server
`morbo -l http://*:3080 server_local.pl`

##Check Webinterface
`firefox http://localhost:3080`

##Screens
To start all processes in one Screen session, please call:

`screen -S XAMBI -c ScreensXambi`

here the config file: 
https://github.com/xpix/xambiserver/blob/master/ScreensXambi

##Configuration
Please read the [Readme.md](https://github.com/xpix/xambiserver/tree/master/cfg) in cfg directory.

##more Informations
- [Subscribe](https://github.com/xpix/xambiserver/tree/master/bin) a MQTT Broker and install an json-api-server call on same or other machine.
- [XAmbi Sensor  and Alarm Modules](https://github.com/xpix/xambiserver/tree/master/XHome)
- [XAmbi API for API json server](https://github.com/xpix/xambiserver/tree/master/XAmbi)

