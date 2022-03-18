import 'package:flutter_openim_sdk/flutter_openim_sdk.dart' as im;
import 'package:get/get.dart';
import 'package:openim_enterprise_chat/src/models/group_member_info.dart';
import 'package:openim_enterprise_chat/src/res/strings.dart';
import 'package:openim_enterprise_chat/src/routes/app_navigator.dart';
import 'package:openim_enterprise_chat/src/utils/im_util.dart';
import 'package:openim_enterprise_chat/src/widgets/custom_dialog.dart';
import 'package:sprintf/sprintf.dart';

enum OpAction { DELETE, ADMIN_TRANSFER, GROUP_CALL }

class GroupMemberListLogic extends GetxController {
  var memberList = <GroupMembersInfo>[].obs;
  var currentCheckedList = <GroupMembersInfo>[].obs;
  var defaultCheckedUidList = <String>[];
  var action = OpAction.DELETE;
  late String gid;
  var maxCount = 7;
  var curCount = 0.obs;

  @override
  void onInit() {
    gid = Get.arguments['gid'];
    var allList = Get.arguments['list'];
    var checkedList = Get.arguments['defaultCheckedUidList'];
    var ac = Get.arguments['action'];
    if (null != ac) action = ac;
    memberList.addAll(allList ?? []);
    defaultCheckedUidList.addAll(checkedList ?? []);
    if (memberList.isNotEmpty) {
      IMUtil.convertToAZList(memberList);
    } else {
      _queryGroupMembers();
    }
    super.onInit();
  }

  void _queryGroupMembers() async {
    var map = await im.OpenIM.iMManager.groupManager.getGroupMemberListMap(
      groupId: gid,
    );
    if (map['data'] is List) {
      var l = (map['data'] as List).map((e) => GroupMembersInfo.fromJson(e));
      memberList.addAll(l);
      IMUtil.convertToAZList(memberList);
    }
  }

  void selectedMember(index) async {
    var info = memberList.elementAt(index);
    if (action == OpAction.DELETE || action == OpAction.GROUP_CALL) {
      if (currentCheckedList.contains(info)) {
        currentCheckedList.remove(info);
      } else {
        currentCheckedList.add(info);
      }
      curCount.value = currentCheckedList.length;
    } else if (action == OpAction.ADMIN_TRANSFER) {
      var confirm = await Get.dialog(CustomDialog(
        title: sprintf(StrRes.confirmTransferGroupToUser, [info.nickName]),
      ));
      if (confirm == true) {
        Get.back(result: info);
      }
    }
  }

  void confirmSelected() async {
    if (action == OpAction.DELETE) {
      var confirm = await Get.dialog(CustomDialog(
        title: StrRes.confirmDelMember,
        rightText: StrRes.sure,
      ));
      if (confirm == true) {
        Get.back(result: currentCheckedList.value);
      }
    } else if (action == OpAction.GROUP_CALL) {
      Get.back(result: currentCheckedList.map((e) => e.userId!).toList());
    }
  }

  void removeContacts(GroupMembersInfo info) {
    currentCheckedList.remove(info);
  }

  bool isMultiModel() {
    return action == OpAction.DELETE || action == OpAction.GROUP_CALL;
  }

  bool isMultiModelConfirm() {
    return action == OpAction.GROUP_CALL;
  }

  void search() async {
    var info = await AppNavigator.startSearchMember(list: memberList.value);
    if (null != info) {
      currentCheckedList.add(info);
      if (action == OpAction.ADMIN_TRANSFER) {
        var confirm = await Get.dialog(CustomDialog(
          title: sprintf(StrRes.confirmTransferGroupToUser, [info.nickName]),
        ));
        if (confirm == true) {
          Get.back(result: info);
        }
      }
    }
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
