import 'dart:io';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:country_code_picker/country_codes.dart';
import 'package:country_code_picker/selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_openim_widget/flutter_openim_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openim_enterprise_chat/src/pages/chat/group_setup/group_member_manager/member_list/member_list_logic.dart';
import 'package:openim_enterprise_chat/src/pages/register/select_avatar/select_avatar_view.dart';
import 'package:openim_enterprise_chat/src/res/images.dart';
import 'package:openim_enterprise_chat/src/res/strings.dart';
import 'package:openim_enterprise_chat/src/res/styles.dart';
import 'package:openim_enterprise_chat/src/routes/app_navigator.dart';
import 'package:openim_enterprise_chat/src/utils/http_util.dart';
import 'package:openim_enterprise_chat/src/utils/im_util.dart';
import 'package:sprintf/sprintf.dart';

import 'bottom_sheet_view.dart';

class IMWidget {
  static final ImagePicker _picker = ImagePicker();

  static final List<CountryCode> _countryCodes =
      codes.map((json) => CountryCode.fromJson(json)).toList();

  static void openPhotoSheet({
    Function(String path, String? url)? onData,
    bool crop = true,
    bool toUrl = true,
    bool isAvatar = false,
    Function(int? index)? onIndexAvatar,
  }) {
    Get.bottomSheet(
      BottomSheetView(
        items: [
          if (isAvatar)
            SheetItem(
              label: StrRes.defaultAvatar,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              onTap: () async {
                var index = await Get.to(() => SelectAvatarPage());
                onIndexAvatar?.call(index);
              },
            ),
          SheetItem(
            label: StrRes.album,
            borderRadius: isAvatar
                ? null
                : BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
            onTap: () {
              PermissionUtil.storage(() async {
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (null != image?.path) {
                  var map = await _uCropPic(
                    image!.path,
                    crop: crop,
                    toUrl: toUrl,
                  );
                  onData?.call(map['path'], map['url']);
                }
              });
            },
          ),
          SheetItem(
            label: StrRes.camera,
            onTap: () {
              PermissionUtil.camera(() async {
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                );
                if (null != image?.path) {
                  var map = await _uCropPic(
                    image!.path,
                    crop: crop,
                    toUrl: toUrl,
                  );
                  onData?.call(map['path'], map['url']);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  static Future<Map<String, dynamic>> _uCropPic(
    String path, {
    bool crop = true,
    bool toUrl = true,
  }) async {
    File? cropFile;
    String? url;
    if (crop) {
      cropFile = await IMUtil.uCrop(path);
    }

    if (toUrl) {
      if (null != cropFile) {
        print('-----------crop path: ${cropFile.path}');
        url = await HttpUtil.uploadImage(path: cropFile.path);
      } else {
        print('-----------source path: $path');
        url = await HttpUtil.uploadImage(path: path);
      }
      print('url:$url');
    }
    return {'path': cropFile?.path ?? path, 'url': url};
  }

  static void showToast(String msg) {
    if (msg.trim().isNotEmpty) EasyLoading.showToast(msg);
  }

  static void openIMCallSheet({
    required String uid,
    required String name,
    String? icon,
  }) {
    Get.bottomSheet(
      BottomSheetView(
        itemBgColor: PageStyle.c_FFFFFF,
        items: [
          SheetItem(
            label: sprintf(StrRes.callX, [name]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            textStyle: PageStyle.ts_666666_16sp,
            height: 53.h,
          ),
          SheetItem(
            label: StrRes.callVoice,
            icon: ImageRes.ic_callVoice,
            alignment: MainAxisAlignment.start,
            onTap: () {},
          ),
          SheetItem(
            label: StrRes.callVideo,
            icon: ImageRes.ic_callVideo,
            alignment: MainAxisAlignment.start,
            onTap: () {},
          ),
        ],
      ),
      // barrierColor: Colors.transparent,
    );
  }

  static void openIMGroupCallSheet({required String gid}) {
    Get.bottomSheet(
      BottomSheetView(
        itemBgColor: PageStyle.c_FFFFFF,
        items: [
          SheetItem(
            label: StrRes.callVoice,
            icon: ImageRes.ic_callVoice,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            alignment: MainAxisAlignment.start,
            onTap: () => _groupCall(gid, 'voice'),
          ),
          SheetItem(
            label: StrRes.callVideo,
            icon: ImageRes.ic_callVideo,
            alignment: MainAxisAlignment.start,
            onTap: () => _groupCall(gid, 'video'),
          ),
        ],
      ),
      // barrierColor: Colors.transparent,
    );
  }

  static _groupCall(String gid, String streamType) async {
    var result = await AppNavigator.startGroupMemberList(
      gid: gid,
      defaultCheckedUidList: [OpenIM.iMManager.uid],
      action: OpAction.GROUP_CALL,
    );
  }

  static Future<String?> showCountryCodePicker() async {
    var result = await Get.dialog(Center(
      child: SelectionDialog(
        _countryCodes,
        [],
        showCountryOnly: false,
        // emptySearchBuilder: widget.emptySearchBuilder,
        // searchDecoration: widget.searchDecoration,
        // searchStyle: widget.searchStyle,
        // textStyle: widget.dialogTextStyle,
        // boxDecoration: widget.boxDecoration,
        showFlag: true,
        // flagWidth: widget.flagWidth,
        // flagDecoration: widget.flagDecoration,
        size: Size(1.sw - 60.w, 1.sh * 3 / 4),
        // backgroundColor: Colors.transparent,
        barrierColor: Colors.transparent,
        // hideSearch: true,
        closeIcon: const Icon(Icons.close),
      ),
    ));
    if (null == result) return null;
    return (result as CountryCode).dialCode;
  }

  static void openMessageSettingSheet(
      {bool isGroup = false, Function(int index)? onTap}) {
    Get.bottomSheet(
      BottomSheetView(
        items: [
          SheetItem(
            label: StrRes.receiveMessageButNotPrompt,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            onTap: () => onTap?.call(0),
          ),
          SheetItem(
            label: isGroup ? StrRes.blockGroupMessages : StrRes.blockFriends,
            onTap: () => onTap?.call(1),
          ),
        ],
      ),
    );
  }
}
