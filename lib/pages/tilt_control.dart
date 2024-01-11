// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
//import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';
import 'package:sensors/sensors.dart';
import '../../services/MahonyAHRS.dart';

class TiltControlView extends StatefulWidget {
  @override
  _TiltControlViewState createState() => _TiltControlViewState();
}

class _TiltControlViewState extends State<TiltControlView> {
  AccelerometerEvent? _eventAccel;
  GyroscopeEvent? _eventGyro;
  StreamSubscription? _accelStream;
  StreamSubscription? _gyroStream;
  Timer? _timer;
  final int _lsmTime = 20;
  late Socket _socket;
  late bool _socketIsConnected;
  late String _status;
  late MahonyAHRS _algorithm;
  late TextEditingController _ipEditingController;
  late TextEditingController _portEditingController;
  bool sensorIsActived = false;
  int _X = 0;
  int _Y = 0;
  int flag = 0;
  int flag_y = 0;
  int tilt = 0;
  String last_y = '';
  String last_x = '';

  @override
  void initState() {
    _algorithm = MahonyAHRS();
    _ipEditingController = TextEditingController();
    _portEditingController = TextEditingController();
    _socketIsConnected = false;
    _status = '';
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
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
      socket.writeln('CONNECT_MOBILE');
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
      if (tilt == 1) {
        double tiltX = _algorithm.Quaternion[1]; // X-axis tilt
        double tiltY = _algorithm.Quaternion[2]; // Y-axis tilt
        tiltX = tiltX * 10;
        tiltY = tiltY * 10;
        int prev_x = _X;
        int prev_y = _Y;
        _X = tiltX.toInt();
        _Y = tiltY.toInt();
        if (_X == 0) {
          flag = 0;
        }
        if (_X.toInt() != prev_x) {
          if (_X <= -3.0) {
            if (flag == 0 || last_x == 'MOVE_RIGHT') {
              sendMessage('MOVE_LEFT');
              last_x = 'MOVE_LEFT';
            }
            flag = 1;
          }
          if (_X >= 3.0) {
            if (flag == 0 || last_x == 'MOVE_LEFT') {
              sendMessage('MOVE_RIGHT');
              last_x = 'MOVE_RIGHT';
            }
            flag = 1;
          }
        }
        if (_Y == 0.0) {
          flag_y = 0;
        }
        if (_Y.toInt() != prev_y) {
          if (_Y >= 3.0) {
            if (flag_y == 0 || last_y == 'MOVE_BACKWARD') {
              sendMessage('MOVE_FORWARD');
              last_y = 'MOVE_FORWARD';
            }
            flag_y = 1;
          }
          if (_Y <= -3.0) {
            if (flag_y == 0 || last_y == 'MOVE_FORWARD') {
              sendMessage('MOVE_BACKWARD');
              last_y = 'MOVE_BACKWARD';
            }
            flag_y = 1;
          }
          //sendMessage('SET_BALANCE_COORD X Y${[_X, _Y]}');
        }
      }
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

  @override
  Widget build(BuildContext context) {
    // Force landscape layout
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tilt Control'),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Container(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      customTextField(
                        _ipEditingController,
                        'IP Server Example: 192.168.0.1',
                      ),
                      SizedBox(height: 10),
                      customTextField(
                        _portEditingController,
                        'PORT Server Example: 8080',
                      ),
                      SizedBox(height: 20),
                      OutlinedButton(
                        child: Text(
                          !_socketIsConnected
                              ? 'Connect Server'
                              : 'Disconnect Server',
                        ),
                        onPressed: () {
                          if (!_socketIsConnected) {
                            _connectSocketChannel();
                          } else {
                            setState(() {
                              _socketIsConnected = false;
                              _status = '';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(_status),
                      SizedBox(height: 20),
                      Text('X: $_X'),
                      Text('Y: $_Y'),
                      SizedBox(height: 10),
                      OutlinedButton(
                        child: Text(!sensorIsActived ? 'Start' : 'Stop'),
                        onPressed: () {
                          if (_socketIsConnected) {
                            if (!sensorIsActived) {
                              tilt = 1;
                              startTimer();
                            } else {
                              tilt = 0;
                              pauseTimer();
                              _algorithm.resetValues();
                            }
                            setState(() {
                              sensorIsActived = !sensorIsActived;
                            });
                          } else {
                            print('Socket is not connected. Cannot start.');
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              if (_socketIsConnected) {
                                sendMessage('MOVE_FORWARD\n');
                                setState(() {
                                  _Y += 40;
                                });
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
                              if (_socketIsConnected) {
                                sendMessage('MOVE_LEFT\n');
                                setState(() {
                                  if (_X >= 30) _X -= 30;
                                });
                                print('Left button pressed');
                              }
                            },
                            child: Icon(Icons.arrow_back),
                          ),
                          SizedBox(width: 50),
                          ElevatedButton(
                            onPressed: () {
                              if (_socketIsConnected) {
                                sendMessage('MOVE_RIGHT\n');
                                setState(() {
                                  _X += 30;
                                });
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
                                sendMessage('MOVE_BACKWARD\n');
                                setState(() {
                                  if (_Y >= 40) _Y -= 40;
                                });
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
              ],
            ),
          );
        },
      ),
    );
  }

  TextField customTextField(TextEditingController controller, String text) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(6.0)),
        ),
        filled: true,
        fillColor: Colors.white60,
        contentPadding: EdgeInsets.all(15.0),
        hintText: text,
      ),
    );
  }
}
