import 'dart:convert';
import 'package:openim_enterprise_chat/src/addfile/initWsconn.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
var c = initWsconn().ch;
void sub(channel) async{
  // final ch = IOWebSocketChannel.connect(
  //   Uri.parse('ws://172.25.6.235:9000/ws'),headers: {"Origin":"*"}
  // );
  // initWsconn().onmessage(jsonEncode(
  //   {
  //     "action": "SUBSCRIBE",
  //     "channel":"$channel",
  //     "data":""
  //   },
  // ));
  c.sink.add(
      jsonEncode(
        {
          "action": "SUBSCRIBE",
          "channel":"$channel",
          "data":""
        },
  ));
  // c.stream.listen(
  //       (data) {
  //     print(data);
  //   }, onError: (error) => print(error),
  // );
  // initWsconn().onlisten();
  print(channel+'sub success');
}

void unsub(channel) async{
  // final ch = IOWebSocketChannel.connect(
  //   Uri.parse('ws://172.25.6.235:9000/ws'),headers: {"Origin":"*"}
  // );
  c.sink.add(
      jsonEncode(
        {
          "action": "UNSUBSCRIBE",
          "channel":"$channel",
          "data":""
        },
      ));
  // c.stream.listen(
  //       (data) {
  //     print(data);
  //   }, onError: (error) => print(error),
  // );
  initWsconn().onlisten();
  print(channel+'unsub success');
}


// void main(List<String> arguments) async {
//
//   final channel = WebSocketChannel.connect(
//     Uri.parse('wss://ws-feed.pro.coinbase.com'),
//   );
//
//   channel.sink.add(
//     jsonEncode(
//       {
//         "type": "subscribe",
//         "channels": [
//           {
//             "name": "ticker",
//             "product_ids": [
//               "BTC-EUR",
//             ]
//           }
//         ]
//       },
//     ),
//   );
//
//   /// Listen for all incoming data
//   channel.stream.listen(
//         (data) {
//       print(data);
//     },
//     onError: (error) => print(error),
//   );
// }