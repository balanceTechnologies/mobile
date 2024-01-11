import 'dart:io';

void main() async {
  final server = await ServerSocket.bind('10.1.229.250', 8080);

  print('Server listening on ${server.address}:${server.port}');

  server.listen((Socket socket) {
    handleConnection(socket);
  });
}

void handleConnection(Socket socket) {
  print('Client connected: ${socket.remoteAddress}:${socket.remotePort}');

  bool receivedConnectMobile = false;

  socket.listen(
    (List<int> data) {
      String message = String.fromCharCodes(data);
      print('Received : $message');

      // Assuming the message format is "COORD X Y"
      if (message.startsWith('SET_BALANCE_COORD')) {
        // Extracting the substring inside the square brackets
        final start = message.indexOf('[');
        final end = message.indexOf(']');

        if (start != -1 && end != -1) {
          final coString = message.substring(start + 1, end);
          final coo = coString
              .split(',')
              .map((e) => double.tryParse(e.trim()))
              .toList();
          //print('Received commands: $coo');
          if (coo.length == 2) {
            final x = coo[0];
            final y = coo[1];

            print('Received commands: x=$x, y=$y');
          } else {
            print('Invalid format');
          }
        }
      } else if (message == 'CONNECT_MOBILE') {
        if (!receivedConnectMobile) {
          print('CONNECT_MOBILE received. Mobile client connected.');
          receivedConnectMobile = true;
        } else {
          print('Already received CONNECT_MOBILE. Closing connection.');
          socket.close();
        }
      }
    },
    onDone: () {
      print(
          'Client disconnected: ${socket.remoteAddress}:${socket.remotePort}');
    },
    cancelOnError: true,
  );
}
