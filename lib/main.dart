import 'package:flutter/material.dart';
import 'package:flutter_sensors_filter_example/pages/remote_control.dart';
import 'package:flutter_sensors_filter_example/pages/tilt_control.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TiltControlView(),
    );
  }
}
