import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_openim_widget/flutter_openim_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:openim_enterprise_chat/src/common/apis.dart';
import 'package:openim_enterprise_chat/src/core/controller/im_controller.dart';
import 'package:openim_enterprise_chat/src/models/contacts_info.dart';
import 'package:openim_enterprise_chat/src/pages/select_contacts/select_contacts_logic.dart';
import 'package:openim_enterprise_chat/src/res/strings.dart';
import 'package:openim_enterprise_chat/src/routes/app_navigator.dart';
import 'package:openim_enterprise_chat/src/utils/data_persistence.dart';
import 'package:openim_enterprise_chat/src/utils/im_util.dart';
import 'package:openim_enterprise_chat/src/widgets/bottom_sheet_view.dart';
import 'package:openim_enterprise_chat/src/widgets/im_widget.dart';
import 'package:openim_enterprise_chat/src/widgets/map_view.dart';
import 'package:openim_enterprise_chat/src/widgets/preview_merge_msg.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'package:uri_to_file/uri_to_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

class ChatLogic extends GetxController {
  var imLogic = Get.find<IMController>();
  var inputCtrl = TextEditingController();
  var focusNode = FocusNode();
  var autoCtrl = ScrollController();

  final refreshController = RefreshController();

  /// Click on the message to process voice playback, video playback, picture preview, etc.
  final clickSubject = rx.PublishSubject<int>();

  ///
  final forceCloseToolbox = rx.PublishSubject<bool>();

  /// The status of message sending,
  /// there are two kinds of success or failure, true success, false failure
  final msgSendStatusSubject = rx.PublishSubject<MsgStreamEv<bool>>();

  /// The progress of sending messages, such as the progress of uploading pictures, videos, and files
  final msgSendProgressSubject = rx.PublishSubject<MsgStreamEv<int>>();

  /// Download progress of pictures, videos, and files
  final downloadProgressSubject = rx.PublishSubject<MsgStreamEv<double>>();

  bool get isSingleChat => null != uid && uid!.trim().isNotEmpty;

  bool get isGroupChat => null != gid && gid!.trim().isNotEmpty;

  String? uid;
  String? gid;
  var name = ''.obs;
  var icon = ''.obs;
  var messageList = <Message>[].obs;
  var lastTime;
  Timer? typingTimer;
  var typing = false.obs;
  var intervalSendTypingMsg = IntervalDo();
  Message? quoteMsg;
  var quoteContent = "".obs;
  var multiSelMode = false.obs;
  var multiSelList = <Message>[].obs;
  var _borderRadius = BorderRadius.only(
    topLeft: Radius.circular(30),
    topRight: Radius.circular(30),
  );

  var atUserNameMappingMap = <String, String>{};
  var atUserInfoMappingMap = <String, UserInfo>{};
  var curMsgAtUser = <String>[];

  var _uuid = Uuid();
  var listViewKey = '1124'.obs;
  var _isFirstLoad = true;
  var _lastCursorIndex = -1;
  var onlineStatus = false.obs;
  var onlineStatusDesc = ''.obs;
  Timer? onlineStatusTimer;

  bool isCurrentChat(Message message) {
    var senderId = message.sendID;
    var receiverId = message.recvID;
    var groupId = message.groupID;
    var sessionType = message.sessionType;
    var isCurSingleChat = sessionType == 1 &&
        isSingleChat &&
        (senderId == uid ||
            // ??????????????????????????????uid???????????????
            senderId == OpenIM.iMManager.uid && receiverId == uid);
    var isCurGroupChat = sessionType == 2 && isGroupChat && gid == groupId;
    return isCurSingleChat || isCurGroupChat;
  }

  void scrollBottom() {
    // ??????listview??????????????????
    if (autoCtrl.offset != 0) {
      listViewKey.value = _uuid.v4();
    }
  }

  @override
  void onReady() {
    getAtMappingMap();
    // getHistoryMsgList();
    readDraftText();
    super.onReady();
  }

  @override
  void onInit() {
    var arguments = Get.arguments;
    uid = arguments['uid'];
    gid = arguments['gid'];
    name.value = arguments['name'];
    icon.value = arguments['icon'];
    // ??????????????????
    _startQueryOnlineStatus();
    // ??????????????????
    imLogic.onRecvNewMessage = (Message message) {
      // ??????????????????????????????
      if (isCurrentChat(message)) {
        // ????????????????????????
        if (message.contentType == MessageType.typing) {
          if (message.content == 'yes') {
            // ??????????????????
            if (null == typingTimer) {
              typing.value = true;
              typingTimer = Timer.periodic(Duration(seconds: 2), (timer) {
                // ????????????????????????
                typing.value = false;
                typingTimer?.cancel();
                typingTimer = null;
              });
            }
          } else {
            // ??????????????????
            typing.value = false;
            typingTimer?.cancel();
            typingTimer = null;
          }
        } else {
          if (!messageList.contains(message)) {
            // messageList.insert(0, message);
            messageList.add(message);
            // scrollBottom();
          }
        }
      }
    };
    // ????????????????????????
    imLogic.onRecvMessageRevoked = (String msgId) {
      messageList.removeWhere((e) => e.clientMsgID == msgId);
    };
    // ????????????????????????
    imLogic.onRecvC2CReadReceipt = (List<HaveReadInfo> list) {
      try {
        // var info = list.firstWhere((read) => read.uid == uid);
        list.forEach((readInfo) {
          if (readInfo.uid == uid) {
            messageList.forEach((e) {
              if (readInfo.msgIDList?.contains(e.clientMsgID) == true) {
                e.isRead = true;
              }
            });
            messageList.refresh();
          }
        });
      } catch (e) {}
    };
    // ??????????????????
    imLogic.onMsgSendProgress = (String msgId, int progress) {
      msgSendProgressSubject.addSafely(
        MsgStreamEv<int>(msgId: msgId, value: progress),
      );
    };

    // ??????????????????
    imLogic.memberEnterSubject.stream.listen((map) {
      var groupId = map['groupId'];
      if (groupId == gid) {
        _putMemberInfo(map['list']);
      }
    });
    // imLogic.onMemberEnter = (groupId, list) {
    //   if (groupId == gid) {
    //     _putMemberInfo(list);
    //   }
    // };
    // ???????????????????????????
    clickSubject.listen((index) {
      print('index:$index');
      parseClickEvent(indexOfMessage(index));
    });

    // ???????????????
    inputCtrl.addListener(() {
      intervalSendTypingMsg.run(
        fuc: () => sendTypingMsg(focus: true),
        milliseconds: 2000,
      );
      clearCurAtMap();
    });

    // ???????????????
    focusNode.addListener(() {
      _lastCursorIndex = inputCtrl.selection.start;
      focusNodeChanged(focusNode.hasFocus);
    });

    // ???????????????
    imLogic.groupInfoUpdatedSubject.listen((value) {
      if (gid == value.groupID) {
        name.value = value.groupName ?? '';
        icon.value = value.faceUrl ?? '';
      }
    });

    // ??????????????????
    imLogic.friendInfoChangedSubject.listen((value) {
      if (uid == value.uid) {
        name.value = value.getShowName();
        icon.value = value.icon ?? '';
      }
    });

    super.onInit();
  }

  void chatSetup() {
    if (null != uid && uid!.isNotEmpty) {
      AppNavigator.startChatSetup(
          uid: uid!, name: name.value, icon: icon.value);
    } else if (null != gid && gid!.isNotEmpty) {
      AppNavigator.startGroupSetup(
          gid: gid!, name: name.value, icon: icon.value);
    }
  }

  void clearCurAtMap() {
    curMsgAtUser.removeWhere((uid) => !inputCtrl.text.contains('@$uid '));
  }

  // ??????id/??????????????????
  // ???????????????????????????id???name
  void getAtMappingMap() async {
    if (isGroupChat) {
      var result = await OpenIM.iMManager.groupManager.getGroupMemberList(
        groupId: gid!,
      );
      _putMemberInfo(result.data);
    }
  }

  /// ?????????????????????
  void _putMemberInfo(List<GroupMembersInfo>? list) {
    list?.forEach((member) {
      atUserNameMappingMap[member.userId!] = member.nickName!;
      atUserInfoMappingMap[member.userId!] = UserInfo(
        uid: member.userId!,
        name: member.nickName,
        icon: member.faceUrl,
      );
    });
    atUserNameMappingMap[OpenIM.iMManager.uid] = StrRes.you;
    atUserInfoMappingMap[OpenIM.iMManager.uid] = OpenIM.iMManager.uInfo;
    DataPersistence.putAtUserMap(gid!, atUserNameMappingMap);
  }

  /// ????????????????????????
  Future<bool> getHistoryMsgList() async {
    var list = await OpenIM.iMManager.messageManager.getHistoryMessageList(
      userID: uid,
      groupID: gid,
      count: 40,
      startMsg: _isFirstLoad ? null : messageList.first,
    );
    if (_isFirstLoad) {
      _isFirstLoad = false;
      messageList..assignAll(list);
      scrollBottom();
    } else {
      messageList.insertAll(0, list);
    }
    return list.length == 40;
  }

  /// ???????????????????????????????????????????????????????????????@??????
  void sendTextMsg() async {
    var content = inputCtrl.text;
    if (content.isEmpty) return;
    var message;
    if (curMsgAtUser.isNotEmpty) {
      // ?????? @ ??????
      message = await OpenIM.iMManager.messageManager.createTextAtMessage(
        text: content,
        atUidList: curMsgAtUser,
      );
    } else if (quoteMsg != null) {
      // ??????????????????
      message = await OpenIM.iMManager.messageManager.createQuoteMessage(
        text: content,
        quoteMsg: quoteMsg!,
      );
    } else {
      // ??????????????????
      message = await OpenIM.iMManager.messageManager.createTextMessage(
        text: content,
      );
    }
    _sendMessage(message);
  }

  /// ????????????
  void sendPicture({required String path}) async {
    var message =
        await OpenIM.iMManager.messageManager.createImageMessageFromFullPath(
      imagePath: path,
    );
    _sendMessage(message);
  }

  /// ????????????
  void sendVoice({required int duration, required String path}) async {
    var message =
        await OpenIM.iMManager.messageManager.createSoundMessageFromFullPath(
      soundPath: path,
      duration: duration,
    );
    _sendMessage(message);
  }

  ///  ????????????
  void sendVideo({
    required String videoPath,
    required String mimeType,
    required int duration,
    required String thumbnailPath,
  }) async {
    var message =
        await OpenIM.iMManager.messageManager.createVideoMessageFromFullPath(
      videoPath: videoPath,
      videoType: mimeType,
      duration: duration,
      snapshotPath: thumbnailPath,
    );
    _sendMessage(message);
  }

  /// ????????????
  void sendFile({required String filePath, required String fileName}) async {
    var message =
        await OpenIM.iMManager.messageManager.createFileMessageFromFullPath(
      filePath: filePath,
      fileName: fileName,
    );
    _sendMessage(message);
  }

  /// ????????????
  void sendLocation({
    required dynamic location,
  }) async {
    var message = await OpenIM.iMManager.messageManager.createLocationMessage(
      latitude: location['latitude'],
      longitude: location['longitude'],
      description: location['description'],
    );
    _sendMessage(message);
  }

  /// ??????
  void sendForwardMsg(int index, {String? userId, String? groupId}) async {
    var message = await OpenIM.iMManager.messageManager.createForwardMessage(
      message: indexOfMessage(index),
    );
    _sendMessage(message, userId: userId, groupId: groupId);
  }

  /// ????????????
  void sendMergeMsg({
    String? userId,
    String? groupId,
  }) async {
    var summaryList = <String>[];
    var title;
    for (var msg in multiSelList) {
      summaryList.add('${msg.senderNickName}???${IMUtil.parseMsg(msg)}');
      if (summaryList.length >= 2) break;
    }
    if (isGroupChat) {
      title = "??????${StrRes.chatRecord}";
    } else {
      var partner1 = OpenIM.iMManager.uInfo.getShowName();
      var partner2 = name.value;
      title = "$partner1???$partner2${StrRes.chatRecord}";
    }
    var message = await OpenIM.iMManager.messageManager.createMergerMessage(
      messageList: multiSelList,
      title: title,
      summaryList: summaryList,
    );
    _sendMessage(message, userId: userId, groupId: groupId);
  }

  /// ????????????????????????
  void sendTypingMsg({bool focus = false}) async {
    if (isSingleChat) {
      OpenIM.iMManager.messageManager.typingStatusUpdate(
        userID: uid!,
        typing: focus,
      );
    }
  }

  /// ????????????
  void sendCarte({required String uid, String? name, String? icon}) async {
    var message = await OpenIM.iMManager.messageManager.createCardMessage(
      data: {"uid": uid, 'name': name, 'icon': icon},
    );
    _sendMessage(message);
  }

  void sendCustomMsg() {
    /* OpenIM.iMManager.messageManager.createCustomMessage(
      data: data,
      extension: extension,
      description: description,
    );*/
  }

  void _sendMessage(Message message, {String? userId, String? groupId}) {
    log('send : ${json.encode(message)}');
    if (null == userId && null == groupId) {
      // messageList.insert(0, message);
      messageList.add(message);
      scrollBottom();
    }
    print('uid:$uid  userId:$userId  gid:$gid    groupId:$groupId');
    _reset();
    OpenIM.iMManager.messageManager
        .sendMessage(
          message: message,
          userID: userId ?? uid,
          groupID: groupId ?? gid,
        )
        .then((value) => _sendSucceeded(message))
        .catchError((e) => _senFailed(message, e))
        .whenComplete(() => _completed());
  }

  ///  ??????????????????
  void _sendSucceeded(Message message) {
    message.status = MessageStatus.succeeded;
    msgSendStatusSubject.addSafely(MsgStreamEv<bool>(
      msgId: message.clientMsgID!,
      value: true,
    ));
  }

  ///  ??????????????????
  void _senFailed(Message message, e) {
    print('send failed e :$e');
    message.status = MessageStatus.failed;
    msgSendStatusSubject.addSafely(MsgStreamEv<bool>(
      msgId: message.clientMsgID!,
      value: false,
    ));
  }

  void _reset() {
    inputCtrl.clear();
    setQuoteMsg(-1);
    closeMultiSelMode();
  }

  /// todo
  void _completed() {
    messageList.refresh();
    // setQuoteMsg(-1);
    // closeMultiSelMode();
    // inputCtrl.clear();
  }

  /// ???????????????????????????
  void setQuoteMsg(int index) {
    print('quote index:$index');
    if (index == -1) {
      quoteMsg = null;
      quoteContent.value = '';
    } else {
      quoteMsg = indexOfMessage(index);
      var name = quoteMsg!.senderNickName;
      quoteContent.value = "$name???${IMUtil.parseMsg(quoteMsg!)}";
    }
  }

  /// ????????????
  void deleteMsg(int index) {
    var message = indexOfMessage(index);
    OpenIM.iMManager.messageManager
        .deleteMessageFromLocalStorage(message: message)
        .then((value) => messageList.remove(message));
  }

  void _deleteMsg() {
    multiSelList.forEach((e) {
      OpenIM.iMManager.messageManager
          .deleteMessageFromLocalStorage(message: e)
          .then((value) => messageList.remove(e));
    });
    closeMultiSelMode();
  }

  /// ????????????
  void revokeMsg(int index) async {
    var message = indexOfMessage(index);
    await OpenIM.iMManager.messageManager.revokeMessage(
      message: message,
    );
    message.contentType = MessageType.revoke;
    messageList.refresh();
  }

  /// ??????
  void forward(int index) async {
    IMWidget.showToast('????????????????????????!');
    // var result =
    //     await AppNavigator.startSelectContacts(action: SelAction.FORWARD);
    //
    // if (null != result) {
    //   sendForwardMsg(index, userId: result['uId'], groupId: result['gId']);
    // }
  }

  /// ?????????????????????
  void markC2CMessageAsRead(int index, Message message, bool visible) {
    print('mark as read???$index   ${message.clientMsgID!}   ${message.isRead}');
    if (isSingleChat &&
        visible &&
        !message.isRead! &&
        message.sendID != OpenIM.iMManager.uid) {
      OpenIM.iMManager.messageManager.markC2CMessageAsRead(
        userID: uid!,
        messageIDList: [message.clientMsgID!],
      );
    }
  }

  /// ????????????
  void mergeForward() {
    IMWidget.showToast('????????????????????????!');
    // Get.bottomSheet(
    //   BottomSheetView(
    //     items: [
    //       SheetItem(
    //         label: StrRes.mergeForward,
    //         borderRadius: _borderRadius,
    //         onTap: () async {
    //           var result = await AppNavigator.startSelectContacts(
    //             action: SelAction.FORWARD,
    //           );
    //           if (null != result) {
    //             sendMergeMsg(userId: result['uId'], groupId: result['gId']);
    //           }
    //         },
    //       ),
    //     ],
    //   ),
    //   barrierColor: Colors.transparent,
    // );
  }

  /// ????????????
  void mergeDelete() {
    Get.bottomSheet(
      BottomSheetView(items: [
        SheetItem(
          label: StrRes.delete,
          borderRadius: _borderRadius,
          onTap: _deleteMsg,
        ),
      ]),
      barrierColor: Colors.transparent,
    );
  }

  void multiSelMsg(int index, bool checked) {
    var msg = indexOfMessage(index);
    if (checked) {
      multiSelList.add(msg);
      multiSelList.sort((a, b) {
        if (a.createTime! > b.createTime!) {
          return 1;
        } else if (a.createTime! < b.createTime!) {
          return -1;
        } else {
          return 0;
        }
      });
    } else {
      multiSelList.remove(msg);
    }
  }

  void openMultiSelMode(int index) {
    multiSelMode.value = true;
    multiSelMsg(index, true);
  }

  void closeMultiSelMode() {
    multiSelMode.value = false;
    multiSelList.clear();
  }

  /// ???????????????????????????????????????
  void closeToolbox() {
    forceCloseToolbox.addSafely(true);
  }

  /// ????????????
  void onTapLocation() async {
    var location = await Get.to(ChatWebViewMap());
    print(location);
    if (null != location) {
      sendLocation(location: location);
    }
  }

  /// ????????????
  void onTapAlbum() async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      Get.context!,
      requestType: RequestType.common,
    );
    if (null != assets) {
      for (var asset in assets) {
        _handleAssets(asset);
      }
    }
  }

  /// ????????????
  void onTapCamera() async {
    final AssetEntity? entity = await CameraPicker.pickFromCamera(
      Get.context!,
      enableRecording: true,
    );
    _handleAssets(entity);
  }

  /// ???????????????????????????
  void onTapFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      // type: FileType.custom,
      // allowedExtensions: ['jpg', 'pdf', 'doc'],
    );
    if (result != null) {
      for (var file in result.files) {
        sendFile(filePath: file.path!, fileName: file.name);
      }
    } else {
      // User canceled the picker
    }
  }

  /// ??????
  void onTapCarte() async {
    var result =
        await AppNavigator.startSelectContacts(action: SelAction.CARTE);
    if (null != result) {
      sendCarte(
        uid: result['uId'],
        name: result['uName'],
        icon: result['uIcon'],
      );
    }
  }

  void _handleAssets(AssetEntity? asset) async {
    if (null != asset) {
      print('--------assets type-----${asset.type}');
      var path = (await asset.file)!.path;
      print('--------assets path-----$path');
      switch (asset.type) {
        case AssetType.image:
          sendPicture(path: path);
          break;
        case AssetType.video:
          var trulyW = asset.width;
          var trulyH = asset.height;
          var scaleW = 100.w;
          var scaleH = scaleW * trulyH / trulyW;
          var data = await asset.thumbDataWithSize(
            scaleW.toInt(),
            scaleH.toInt(),
          );
          print('-----------video thumb build success----------------');
          final result = await ImageGallerySaver.saveImage(
            data!,
            isReturnImagePathOfIOS: true,
          );
          var thumbnailPath = result['filePath'];
          print('-----------gallery saver : ${json.encode(result)}---------');
          var filePrefix = 'file://';
          var uriPrefix = 'content://';
          if ('$thumbnailPath'.contains(filePrefix)) {
            thumbnailPath = thumbnailPath.substring(filePrefix.length);
          } else if ('$thumbnailPath'.contains(uriPrefix)) {
            // Uri uri = Uri.parse(thumbnailPath); // Parsing uri string to uri
            File file = await toFile(thumbnailPath);
            thumbnailPath = file.path;
          }
          sendVideo(
            videoPath: path,
            mimeType: asset.mimeType ?? CommonUtil.getMediaType(path) ?? '',
            duration: asset.duration,
            thumbnailPath: thumbnailPath,
          );
          // sendVoice(duration: asset.duration, path: path);
          break;
        default:
          break;
      }
    }
  }

  /// ????????????????????????
  void parseClickEvent(Message msg) async {
    // log("message:${json.encode(msg)}");
    if (msg.contentType == MessageType.picture) {
      IMUtil.openPicture(msg);
    } else if (msg.contentType == MessageType.video) {
      IMUtil.openVideo(msg);
    } else if (msg.contentType == MessageType.file) {
      IMUtil.openFile(msg);
      // OpenFile.open(filePath);
    } else if (msg.contentType == MessageType.card) {
      var info = ContactsInfo.fromJson(json.decode(msg.content!));
      AppNavigator.startFriendInfo(info: info);
    } else if (msg.contentType == MessageType.merger) {
      Get.to(
        () => PreviewMergeMsg(
          title: msg.mergeElem!.title!,
          messageList: msg.mergeElem!.multiMessage!,
        ),
        preventDuplicates: false,
      );
    } else if (msg.contentType == MessageType.location) {
      var location = msg.locationElem;
      Map detail = json.decode(location!.description!);
      Get.to(() => MapView(
            latitude: location.latitude!,
            longitude: location.longitude!,
            addr1: detail['name'],
            addr2: detail['addr'],
          ));
    }
  }

  /// ??????????????????
  void onTapQuoteMsg(index) {
    var msg = indexOfMessage(index);
    parseClickEvent(msg.quoteElem!.quoteMessage!);
  }

  /// ??????????????????
  void call() {
    if (isGroupChat) {
      IMWidget.openIMGroupCallSheet(gid: gid!);
      return;
    }
    IMWidget.openIMCallSheet(uid: uid!, name: name.value, icon: icon.value);
  }

  /// ????????????????????????@??????
  void onLongPressLeftAvatar(int index) {
    var msg = indexOfMessage(index);
    if (isGroupChat) {
      var uid = msg.sendID!;
      var uname = msg.senderNickName;
      if (curMsgAtUser.contains(uid)) return;
      curMsgAtUser.add(uid);
      // ????????????????????????
      // ??????????????????????????????
      var cursor = inputCtrl.selection.base.offset;
      if (cursor < 0) cursor = 0;
      print('===================cursor:$cursor');
      // ?????????????????????
      var start = inputCtrl.text.substring(0, cursor);
      print('===================start:$start');
      // ?????????????????????
      var end = inputCtrl.text.substring(cursor);
      print('===================end:$end');
      var at = '@$uid ';
      inputCtrl.text = '$start$at$end';
      inputCtrl.selection = TextSelection.fromPosition(TextPosition(
        offset: '$start$at'.length,
      ));
      _lastCursorIndex = inputCtrl.selection.start;
      print('$curMsgAtUser');
    }
  }

  void onTapLeftAvatar(int index) {
    var msg = indexOfMessage(index);
    var info = ContactsInfo.fromJson({
      'uid': msg.sendID!,
      'name': msg.senderNickName,
      'icon': msg.senderFaceUrl,
      'flag': 1,
    });
    AppNavigator.startFriendInfo(info: info);
    // Get.toNamed(AppRoutes.FRIEND_INFO, arguments: info);
  }

  void clickAtText(id) {
    if (null != atUserInfoMappingMap[id]) {
      AppNavigator.startFriendInfo(info: atUserInfoMappingMap[id]);
    }
  }

  void clickLinkText(url, type) async {
    print('--------link  type:$type-------url: $url---');
    if (type == PatternType.AT) {
      clickAtText(url);
      return;
    }
    if (await canLaunch(url)) {
      await launch(url);
    }
    // await canLaunch(url) ? await launch(url) : throw 'Could not launch $url';
  }

  /// ????????????
  void readDraftText() {
    var draftText = Get.arguments['draftText'];
    print('readDraftText:$draftText');
    if (null != draftText && "" != draftText) {
      var map = json.decode(draftText!);
      String text = map['text'];
      // String? quoteMsgId = map['quoteMsgId'];
      Map<String, dynamic> atMap = map['at'];
      print('text:$text  atMap:$atMap');
      atMap.forEach((key, value) {
        if (!curMsgAtUser.contains(key)) curMsgAtUser.add(key);
        atUserNameMappingMap.putIfAbsent(key, () => value);
      });
      inputCtrl.text = text;
      inputCtrl.selection = TextSelection.fromPosition(TextPosition(
        offset: text.length,
      ));
      // if (null != quoteMsgId) {
      //   var index = messageList.indexOf(Message()..clientMsgID = quoteMsgId);
      //   print('quoteMsgId index:$index  length:${messageList.length}');
      //   setQuoteMsg(index);
      //   print('quoteMsgId index:$index  length:${messageList.length}');
      // }
      if (text.isNotEmpty) {
        focusNode.requestFocus();
      }
    }
  }

  /// ????????????draftText
  String createDraftText() {
    var atMap = <String, dynamic>{};
    curMsgAtUser.forEach((uid) {
      atMap[uid] = atUserNameMappingMap[uid];
    });
    if (inputCtrl.text.isEmpty) {
      return "";
    }
    return json.encode({
      'text': inputCtrl.text,
      'at': atMap,
      // 'quoteMsgId': quoteMsg?.clientMsgID,
    });
  }

  /// ?????????????????????
  bool exit() {
    if (multiSelMode.value) {
      closeMultiSelMode();
      return false;
    }
    Get.back(result: createDraftText());
    return true;
  }

  void focusNodeChanged(bool hasFocus) {
    sendTypingMsg(focus: hasFocus);
    if (hasFocus) {
      print('focus:$hasFocus');
      scrollBottom();
    }
  }

  void copy(index) {
    var msg = indexOfMessage(index);
    IMUtil.copy(text: msg.content!);
  }

  Message indexOfMessage(int index) =>
      IMUtil.calChatTimeInterval(messageList).reversed.elementAt(index);

  ValueKey itemKey(int index) => ValueKey(indexOfMessage(index).clientMsgID!);

  @override
  void onClose() {
    // inputCtrl.dispose();
    // focusNode.dispose();
    clickSubject.close();
    forceCloseToolbox.close();
    msgSendStatusSubject.close();
    msgSendProgressSubject.close();
    downloadProgressSubject.close();
    onlineStatusTimer?.cancel();
    super.onClose();
  }

  String? getShowTime(int index) {
    var info = indexOfMessage(index);
    if (info.ext == true) {
      return IMUtil.getChatTimeline(info.sendTime!);
    }
    return null;
  }

  void clearAllMessage() {
    messageList.clear();
  }

  void onStartVoiceInput() {
    // SpeechToTextUtil.instance.startListening((result) {
    //   inputCtrl.text = result.recognizedWords;
    // });
  }

  void onStopVoiceInput() {
    // SpeechToTextUtil.instance.stopListening();
  }

  /// ????????????
  void onAddEmoji(String emoji) {
    var input = inputCtrl.text;
    if (_lastCursorIndex != -1 && input.isNotEmpty) {
      var part1 = input.substring(0, _lastCursorIndex);
      var part2 = input.substring(_lastCursorIndex);
      inputCtrl.text = '$part1$emoji$part2';
      _lastCursorIndex = _lastCursorIndex + emoji.length;
    } else {
      inputCtrl.text = '$input$emoji';
      _lastCursorIndex = emoji.length;
    }
    inputCtrl.selection = TextSelection.fromPosition(TextPosition(
      offset: _lastCursorIndex,
    ));
  }

  /// ????????????
  void onDeleteEmoji() {
    final input = inputCtrl.text;
    final regexEmoji = emojiFaces.keys
        .toList()
        .join('|')
        .replaceAll('[', '\\[')
        .replaceAll(']', '\\]');
    final list = [regexAt, regexEmoji];
    final pattern = '(${list.toList().join('|')})';
    final atReg = RegExp(regexAt);
    final emojiReg = RegExp(regexEmoji);
    var reg = RegExp(pattern);
    if (reg.hasMatch(input)) {
      var match = reg.allMatches(inputCtrl.text).last;
      var matchText = match.group(0)!;
      var start = match.start;
      var end = start + matchText.length;
      // ??????????????????
      if (end == input.length) {
        if (atReg.hasMatch(matchText)) {
          String id = matchText.replaceFirst("@", "").trim();
          if (curMsgAtUser.remove(id)) {
            inputCtrl.text = input.replaceRange(start, end, '');
          } else {
            inputCtrl.text = input.substring(0, input.length - 1);
          }
        } else if (emojiReg.hasMatch(matchText)) {
          inputCtrl.text = input.replaceRange(start, end, "");
        }
      } else {
        inputCtrl.text = input.substring(0, input.length - 1);
      }
    } else {
      if (input.isNotEmpty) {
        inputCtrl.text = input.substring(0, input.length - 1);
      }
    }
    _lastCursorIndex = inputCtrl.text.length;
  }

  /// ??????????????????
  void _getOnlineStatus(List<String> uidList) {
    Apis.onlineStatus(uidList: uidList).then((list) {
      list.forEach((e) {
        if (e.status == 'online') {
          // IOSPlatformStr     = "IOS"
          // AndroidPlatformStr = "Android"
          // WindowsPlatformStr = "Windows"
          // OSXPlatformStr     = "OSX"
          // WebPlatformStr     = "Web"
          // MiniWebPlatformStr = "MiniWeb"
          // LinuxPlatformStr   = "Linux"
          final pList = <String>[];
          for (var platform in e.detailPlatformStatus!) {
            if (platform.platform == "Android" || platform.platform == "IOS") {
              pList.add(StrRes.phoneOnline);
            } else if (platform.platform == "Windows") {
              pList.add(StrRes.pcOnline);
            } else if (platform.platform == "Web") {
              pList.add(StrRes.webOnline);
            } else if (platform.platform == "MiniWeb") {
              pList.add(StrRes.webMiniOnline);
            } /* else {
              onlineStatus[e.userID!] = StrRes.online;
            }*/
          }
          onlineStatusDesc.value = '${pList.join('/')}${StrRes.online}';
          onlineStatus.value = true;
        } else {
          onlineStatusDesc.value = StrRes.offline;
          onlineStatus.value = false;
        }
      });
    });
  }

  void _startQueryOnlineStatus() {
    if (null != uid && uid!.isNotEmpty && onlineStatusTimer == null) {
      _getOnlineStatus([uid!]);
      onlineStatusTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        _getOnlineStatus([uid!]);
      });
    }
  }

  String getSubTile() => typing.value ? StrRes.typing : onlineStatusDesc.value;

  bool showOnlineStatus() => !typing.value && onlineStatusDesc.isNotEmpty;
}
