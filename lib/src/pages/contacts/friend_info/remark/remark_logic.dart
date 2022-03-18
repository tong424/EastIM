import 'package:flutter/cupertino.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_enterprise_chat/src/res/strings.dart';
import 'package:openim_enterprise_chat/src/widgets/im_widget.dart';

class FriendRemarkLogic extends GetxController {
  late UserInfo info;
  var inputCtrl = TextEditingController();
  // var focusNode = FocusNode();

  void save() {
    // if (inputCtrl.text.isEmpty) {
    //   IMWidget.showToast(StrRes.remarkNotEmpty);
    //   return;
    // }
    OpenIM.iMManager.friendshipManager
        .setFriendInfo(uid: info.uid, comment: inputCtrl.text.trim())
        .then(
      (value) {
        IMWidget.showToast(StrRes.saveSuccessfully);
        Get.back(result: inputCtrl.text.trim());
        return value;
      },
    ).catchError((e) => IMWidget.showToast(StrRes.saveFailed));
  }

  @override
  void onInit() {
    info = Get.arguments;
    inputCtrl.text = info.comment ?? '';
    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    inputCtrl.dispose();
    // focusNode.dispose();
    super.onClose();
  }
}
