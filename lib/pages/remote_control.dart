// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'dart:convert';
import 'dart:io';
//import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';
import 'package:sensors/sensors.dart';
import '../../services/MahonyAHRS.dart';

class RemoteControlView extends StatefulWidget {
  @override
  _RemoteControlViewState createState() => _RemoteControlViewState();
}

class _RemoteControlViewState extends State<RemoteControlView> {
  @override
  // ignore: override_on_non_overriding_member
  AccelerometerEvent? _eventAccel;
  GyroscopeEvent? _eventGyro;
  StreamSubscription? _accelStream;
  StreamSubscription? _gyroStream;
  Timer? _timer;
  final int _lsmTime = 20;
  late Socket _socket;
  late bool _socketIsConnected;
  // ignore: unused_field
  late String _status;
  late MahonyAHRS _algorithm;
  late TextEditingController _ipEditingController;
  late TextEditingController _portEditingController;
  bool sensorIsActived = false;
  int _X = 0;
  int _Y = 0;

  @override
  void initState() {
    _algorithm = MahonyAHRS();
    _ipEditingController = TextEditingController();
    _portEditingController = TextEditingController();
    _socketIsConnected = false;
    _status = '';
    super.initState();
  }

  Future<void> _connectSocketChannel() async {
    if (_ipEditingController.text.isEmpty ||
        _portEditingController.text.isEmpty) {
      return;
    }

    var serverAddress = _ipEditingController.text;
    var serverPort = int.tryParse(_portEditingController.text) ?? 8080;

    try {
      print("connection true");
      print(serverAddress);
      print(serverPort);

      // Use Socket.connect for dart:io sockets
      var socket = await Socket.connect(serverAddress, serverPort);
      socket.write('GET /path HTTP/1.1\r\n'
          'Host: $serverAddress\r\n'
          'Connection: close\r\n\r\n');
      socket.writeln('CONNECT_MOBILE\n');
      await socket.flush();

      // Note: Use dart:io Socket, not IO.Socket
      _socket = socket;
      connectionListener(true);
    } catch (e) {
      print('Error connecting to the server: $e');
      connectionListener(false);
    }
  }

  void sendMessage(message) {
    try {
      _socket.writeln(message);
    } catch (e) {
      setState(() {
        _status = 'Status: Connection problems, try to connect again';
        _socketIsConnected = false;
      });
    }
  }

  void connectionListener(bool connected) {
    setState(() {
      _status = 'Status : ' + (connected ? 'Connected' : 'Failed to connect');
      _socketIsConnected = connected;
    });
  }

  void setPosition(
      AccelerometerEvent currentAccel, GyroscopeEvent currentGyro) {
    if (currentAccel == null && currentGyro == null) {
      return;
    }

    _algorithm.update(
      currentAccel.x,
      currentAccel.y,
      currentAccel.z,
      currentGyro.x,
      currentGyro.y,
      currentGyro.z,
    );

    if (_socketIsConnected) {
      //sendMessage('SET_BALANCE_COORD $_X $_Y');
    }
  }

  void startTimer() {
    if (_accelStream == null && _gyroStream == null) {
      _accelStream = accelerometerEvents.listen((AccelerometerEvent event) {
        setState(() {
          _eventAccel = event;
        });
      });
      _gyroStream = gyroscopeEvents.listen((GyroscopeEvent event) {
        setState(() {
          _eventGyro = event;
        });
      });
    } else {
      _accelStream?.resume();
      _gyroStream?.resume();
    }

    if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(Duration(milliseconds: _lsmTime), (_) {
        setPosition(_eventAccel!, _eventGyro!);
      });
    }
  }

  void pauseTimer() {
    _timer?.cancel();
    _accelStream?.pause();
    _gyroStream?.pause();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _accelStream?.cancel();
    _gyroStream?.cancel();
    _socket.close();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Remote Control'),
      ),
      body: Container(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            customTextField(
                _ipEditingController, 'IP Server Exemple: 192.168.0.1'),
            Padding(padding: EdgeInsets.only(bottom: 5.0)),
            customTextField(
                _portEditingController, 'PORT Server Exemple: 8080'),
            Padding(padding: EdgeInsets.only(bottom: 20.0)),
            OutlinedButton(
              child: Text(
                  !_socketIsConnected ? 'Connect Server' : 'Disconnect Server'),
              onPressed: () {
                if (!_socketIsConnected) {
                  _connectSocketChannel();
                } else {
                  setState(() {
                    _socketIsConnected = false;
                    _socket.close();
                    _status = '';
                  });
                }
              },
            ),
            SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (_socketIsConnected) {
// Handle up button press
                      sendMessage('MOVE_FORWARD\n');
                      setState(() {
                        _Y += 40;
                      });
                      //sendMessage('SET_BALANCE_COORD $_X $_Y');
                      print('Up button pressed');
                    }
                  },
                  child: Icon(Icons.arrow_upward),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Handle left button press
                    if (_socketIsConnected) {
                      sendMessage('MOVE_LEFT\n');
                      setState(() {
                        if (_X >= 30) _X -= 30;
                      });
                      //sendMessage('SET_BALANCE_COORD $_X $_Y');
                      print('Left button pressed');
                    }
                  },
                  child: Icon(Icons.arrow_back),
                ),
                SizedBox(width: 50),
                ElevatedButton(
                  onPressed: () {
                    // Handle right button press
                    if (_socketIsConnected) {
                      sendMessage('MOVE_RIGHT\n');
                      setState(() {
                        _X += 30;
                      });
                      //sendMessage('SET_BALANCE_COORD $_X $_Y');

                      print('Right button pressed');
                    }
                  },
                  child: Icon(Icons.arrow_forward),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (_socketIsConnected) {
                      // Handle down button press
                      sendMessage('MOVE_BACKWARD\n');
                      setState(() {
                        if (_Y >= 40) _Y -= 40;
                      });
                      //sendMessage('SET_BALANCE_COORD X Y $_X $_Y');

                      print('Down button pressed');
                    }
                  },
                  child: Icon(Icons.arrow_downward),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextField customTextField(TextEditingController controller, String text) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6.0))),
          filled: true,
          fillColor: Colors.white60,
          contentPadding: EdgeInsets.all(15.0),
          hintText: text),
    );
  }
}
