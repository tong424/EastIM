import 'package:dotted_decoration/dotted_decoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim_enterprise_chat/src/res/images.dart';
import 'package:openim_enterprise_chat/src/res/strings.dart';
import 'package:openim_enterprise_chat/src/res/styles.dart';
import 'package:openim_enterprise_chat/src/widgets/avatar_view.dart';
import 'package:openim_enterprise_chat/src/widgets/titlebar.dart';
import 'package:openim_enterprise_chat/src/widgets/touch_close_keyboard.dart';

import 'name_setup_logic.dart';

class GroupNameSetupPage extends StatelessWidget {
  final logic = Get.find<GroupNameSetupLogic>();

  @override
  Widget build(BuildContext context) {
    return TouchCloseSoftKeyboard(
      child: Scaffold(
        appBar: EnterpriseTitleBar.back(
          showShadow: false,
        ),
        backgroundColor: PageStyle.c_FFFFFF,
        body: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              left: 42.w,
              right: 42.w,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 67.h,
                ),
                Text(
                  StrRes.modifyGroupName,
                  style: PageStyle.ts_333333_20sp,
                ),
                SizedBox(
                  height: 10.h,
                ),
                Text(
                  StrRes.modifyGroupNameHint,
                  style: PageStyle.ts_333333_15sp,
                ),
                SizedBox(
                  height: 46.h,
                ),
                Container(
                  decoration: DottedDecoration(),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      bottom: BorderSide(
                        color: PageStyle.c_333333_opacity40p,
                        width: 0.5.h,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      AvatarView(
                        size: 44.h,
                        isCircle: false,
                        url: logic.info.value.faceUrl,
                      ),
                      SizedBox(
                        width: 11.w,
                      ),
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          controller: logic.nameCtrl,
                          style: PageStyle.ts_333333_16sp,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => logic.clear(),
                        behavior: HitTestBehavior.translucent,
                        child: Container(
                          height: 44.h,
                          child: Center(
                            child: Image.asset(
                              ImageRes.ic_clearInput,
                              color: PageStyle.c_999999,
                              width: 18.h,
                              height: 18.h,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 259.h,
                ),
                Obx(() => Ink(
                      width: 149.w,
                      height: 34.h,
                      decoration: BoxDecoration(
                        color: PageStyle.c_1B72EC.withOpacity(
                          logic.enabled.value ? 1 : 0.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: InkWell(
                        onTap: () => logic.modifyGroupName(),
                        child: Center(
                          child: Text(
                            StrRes.finished,
                            style: PageStyle.ts_FFFFFF_16sp,
                          ),
                        ),
                      ),
                    ))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
