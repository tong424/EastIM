import 'package:web_socket_channel/io.dart';

class initWsconn{
  final ch = IOWebSocketChannel.connect(
  Uri.parse('ws://172.25.6.235:9000/ws'),headers: {"Origin":"*"});

  onlisten(){
    ch.stream.listen(
        (data) {
      print(data);
    }, onError: (error) => print(error),
  );
  }
  onmessage(data){
    ch.sink.add(data
    );
  }
}

// Future<IOWebSocketChannel> initWsconn()async{
//
// }
