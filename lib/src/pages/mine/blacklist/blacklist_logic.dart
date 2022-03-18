import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim_enterprise_chat/src/res/strings.dart';
import 'package:openim_enterprise_chat/src/widgets/custom_dialog.dart';

class BlacklistLogic extends GetxController {
  var blacklist = <UserInfo>[].obs;

  void getBlacklist() async {
    var list = await OpenIM.iMManager.friendshipManager.getBlackList();
    blacklist.addAll(list);
  }

  Future<bool> remove(UserInfo info) async {
    var confirm = await Get.dialog(CustomDialog(
      title: StrRes.removeBlacklistHint,
    ));
    if (confirm == true) {
      await OpenIM.iMManager.friendshipManager.deleteFromBlackList(
        uid: info.uid,
      );
      blacklist.remove(info);
    } else {
      return false;
    }
    // await OpenIM.iMManager.friendshipManager.deleteFromBlackList(
    //   uid: info.uid,
    // );
    // blacklist.remove(info);
    return true;
  }

  @override
  void onReady() {
    getBlacklist();
    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
  }
}
