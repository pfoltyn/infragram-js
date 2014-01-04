/*
 This file is part of infragram-js.

 infragram-js is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 2 of the License, or
 (at your option) any later version.

 infragram-js is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with infragram-js.  If not, see <http://www.gnu.org/licenses/>.
*/

require('./db');

/**
 * Module dependencies.
 */

var express = require('express');
var routes = require('./routes');

var http = require('http');
var path = require('path');
var fs = require('fs');

var app = express();
var server = http.createServer(app);
var io = require('socket.io').listen(server);

// all environments
app.set('port', process.env.PORT || 8001);
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');
app.use(express.favicon());
app.use(express.logger('dev'));
app.use(express.json());
app.use(express.urlencoded());
app.use(express.methodOverride());
app.use(app.router);
app.use(require('stylus').middleware(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname, 'public')));

// development only
if ('development' == app.get('env')) {
    app.use(express.errorHandler());
}

app.get('/', routes.index);
app.get('/i/:id', routes.show);
app.post('/create', routes.create);
app.get('/delete/:id', routes.delete);
app.get('/static/sandbox/', function (req, res) { res.redirect('/sandbox/'); });

server.listen(app.get('port'), function () {
    console.log('Express server listening on port ' + app.get('port'));
});

var Files = {};

io.sockets.on('connection', function (socket) {
    //data contains the variables that we passed through in the html file
  	socket.on('start', function (data) {
        var Name = data['name'];
        //Create a new Entry in The Files Variable
        Files[Name] = {
            'file_size': data['size'],
            'data': '',
            'downloaded': 0
        }
        fs.open('./public/upload/temp/' + Name, 'w', 0755, function (err, fd) {
            if (err) {
                console.log(err);
            }
            else {
                //We store the file handler so we can write to it later
                Files[Name]['handler'] = fd;
                socket.emit('more_data', { 'place' : 0, 'percent' : 0 });
            }
        });
	});

	socket.on('upload', function (data) {
        var Name = data['name'];
        Files[Name]['downloaded'] += data['data'].length;
        Files[Name]['data'] += data['data'];
        //If File is Fully Uploaded
        if(Files[Name]['downloaded'] == Files[Name]['file_size']) {
            fs.write(Files[Name]['handler'], Files[Name]['data'], null, 'Binary', function (err, Writen) {
                fs.close(Files[Name]['handler'], function () {});
                fs.rename('./public/upload/temp/' + Name, './public/upload/' + Name, function () {
                    socket.emit('done', {'image' : './public/upload/' + Name});
                });
                fs.unlink('./public/upload/temp/' + Name, function () {});
            });
        }
        //If the Data Buffer reaches 10MB
        else if (Files[Name]['data'].length > 10485760) {
            fs.write(Files[Name]['handler'], Files[Name]['data'], null, 'Binary', function (err, Writen) {
                //Reset The Buffer
                Files[Name]['data'] = '';
                var Place = Files[Name]['downloaded'] / 524288;
                var Percent = (Files[Name]['downloaded'] / Files[Name]['file_size']) * 100;
                socket.emit('more_data', {'place': Place, 'percent': Percent});
            });
        }
        else {
            var Place = Files[Name]['downloaded'] / 524288;
            var Percent = (Files[Name]['downloaded'] / Files[Name]['file_size']) * 100;
            socket.emit('more_data', {'place': Place, 'percent': Percent});
        }
    });
});
