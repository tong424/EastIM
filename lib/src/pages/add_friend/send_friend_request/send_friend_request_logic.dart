import 'package:flutter/cupertino.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_enterprise_chat/src/res/strings.dart';
import 'package:openim_enterprise_chat/src/widgets/im_widget.dart';

class SendFriendRequestLogic extends GetxController {
  UserInfo? _userInfo;
  var reasonCtrl = TextEditingController();
  var remarkNameCtrl = TextEditingController();

  void addFriend() {
    if (null != _userInfo) {
      print('addFriend:${_userInfo!.uid}');
      OpenIM.iMManager.friendshipManager
          .addFriend(uid: _userInfo!.uid, reason: reasonCtrl.text)
          .then((value) => _sendSuc())
          .catchError((e) => _sendFail());
    }
  }

  void _sendSuc() {
    IMWidget.showToast(StrRes.sendSuccessfully);
    Get.back();
  }

  void _sendFail() {
    IMWidget.showToast(StrRes.sendFailed);
  }

  @override
  void onInit() {
    _userInfo = Get.arguments;
    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    reasonCtrl.dispose();
    remarkNameCtrl.dispose();
    super.onClose();
  }
}
