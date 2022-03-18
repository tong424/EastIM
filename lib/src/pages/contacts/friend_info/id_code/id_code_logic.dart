import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_enterprise_chat/src/utils/im_util.dart';

class FriendIdCodeLogic extends GetxController {
  late UserInfo info;

  @override
  void onInit() {
    info = Get.arguments;
    super.onInit();
  }

  void copy() {
    IMUtil.copy(text: info.uid);
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }
}
