import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:openim_enterprise_chat/src/common/urls.dart';
import 'package:openim_enterprise_chat/src/models/login_certificate.dart';
import 'package:openim_enterprise_chat/src/utils/http_util.dart';
import 'package:openim_enterprise_chat/src/utils/im_util.dart';
import 'package:openim_enterprise_chat/src/widgets/im_widget.dart';

Future<bool> LoginRequest(username, password) async {
  var baseurl = 'http://172.25.6.235:8080/login';
  var httpClient = new HttpClient();
  var url = baseurl + '?' + 'userID=' + username + '&password=' + password;
  var result;
  try {
    var request = await httpClient.getUrl(Uri.parse(url));
    var response = await request.close();
    print(response.statusCode);
    if (response.statusCode == HttpStatus.ok) {
      var json = await response.transform(utf8.decoder).join();
      var data = jsonDecode(json);
      result = data['code'];
      // print(result == '0');
      if(result == '0'){return true;}else{return false;}
    } else {
      print('Error request:\nHttp status ${response.statusCode}');
      return false;
    }
  } catch (exception) {
    print('Failed to request');
    return false;
  }
}