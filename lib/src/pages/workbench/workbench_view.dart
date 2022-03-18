import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openim_enterprise_chat/src/addfile/initWsconn.dart';
import 'package:openim_enterprise_chat/src/pages/signal/subusub.dart';
import 'package:openim_enterprise_chat/src/pages/workbench/workbench_logic.dart';
import 'package:openim_enterprise_chat/src/res/strings.dart';
import 'package:openim_enterprise_chat/src/res/styles.dart';
import 'package:openim_enterprise_chat/src/utils/ExpandedList.dart';
import 'package:openim_enterprise_chat/src/utils/data_persistence.dart';
import 'package:openim_enterprise_chat/src/utils/organ-node.dart';
import 'package:openim_enterprise_chat/src/widgets/titlebar.dart';
import 'package:sp_util/sp_util.dart';
import 'package:web_socket_channel/io.dart';
import 'package:shared_preferences/shared_preferences.dart';
class WorkbenchPage extends StatefulWidget {
  @override
  _WorkbenchPageState createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage>
    with SingleTickerProviderStateMixin {
  final logic = Get.find<WorkbenchLogic>();
  var pageData;
  var epicsList = [];
  var mdsPlusList = [];
  var logList = [];
  late TabController _controller;
  late StateSetter _reloadTextSetter;
  late List<String> activeWrite;
  late List<String> activeRead;
  late List<int> active;
  var lockReconnect = false;//避免重复连接
  late List<String> list1;
  late List<String> list2;
  late List<String> list3;
  late List<String> sublist;
  late IOWebSocketChannel _channel;
  var loginCertificate = DataPersistence.getLoginCertificate();
  String? get uid => loginCertificate?.uid;

  @override
  void initState() {
    super.initState();
    WsConnect();      //websockets连接
    initData();       //数据初始化
    onListen();       //监听，心跳，（重连）
    _controller = TabController(length: pageData.length, vsync: ScrollableState());
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: PageStyle.c_FFFFFF,
        appBar: AppBar(
          title: Text("EastIM", style: TextStyle(
            color: Colors.blueAccent
          )),
          centerTitle:true,
          backgroundColor:Colors.white,
          elevation:2,
          bottom: TabBar(
            controller: _controller,
            indicatorWeight: 3,
            indicatorColor:Colors.blueAccent,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.black,
            labelStyle: TextStyle(fontSize: 16.0),
            tabs: _tabs(),
          ),
        ),
        floatingActionButton: FloatingActionButton(
              child: Icon(Icons.add,color: Colors.white,size: 40,),
              onPressed: (){
                _showDialog();
              },
              backgroundColor: Colors.blueAccent
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            body: TabBarView(
            controller: _controller, children:_tabViews()));
  }

  List <Widget> _tabs(){
    List <Widget> tabList = [];
    pageData.forEach((page) {
      tabList.add(Tab(text: page["title"],),);});
    return tabList;
  }
  List <Widget> _tabViews(){
    List <Widget> tabViewList = [];
    pageData.forEach((page) {
      var contents = page["content"];
      tabViewList.add(
        ListView(children: _listViewChildren(contents)),);});
    return tabViewList;
  }
  List <Widget> _listViewChildren(List contents){
    List <Widget> children = [];
    if(contents.isNotEmpty){
      contents.forEach((content) {
        children.add(ListTile(title: Text("${content}"),));});
    }
    return children;
  }

    _renderList() {
    List<Widget> list = [];
    list.add(CustomScrollView(
          key: PageStorageKey<String>("tab_0"),
          slivers: [
            SliverFixedExtentList(
                delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                    return Container(
                      color: Colors.white,
                      height: 50,
                      child: Text(active.toString()),
                    );
                  },
                  childCount: 1,
                ),
                itemExtent: 100)
          ],
        ));
    list.add(CustomScrollView(
          key: PageStorageKey<String>("tab_1"),
          slivers: [
            SliverFixedExtentList(
                delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                    return Container(
                      color: Colors.white,
                      height: 50,
                      child: Text(active.toString()),
                    );
                  },
                  childCount: 2,
                ),
                itemExtent: 100)
          ],
        ));
    list.add(CustomScrollView(
          key: PageStorageKey<String>("tab_2"),
          slivers: [
            SliverFixedExtentList(
                delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                    return Container(
                      color: Colors.white,
                      height: 50,
                      child: Text(active.toString()),
                    );
                  },
                  childCount: 3,
                ),
                itemExtent: 100)
          ],
        ));
    return list;
    }

  _buildButton(channel){
    return new SizedBox(
        height: 30.0,
        width:100.0,
        child: ElevatedButton (
          onPressed: (){
            (active[channel] == 1)?sub(sublist[channel]):unsub(sublist[channel]);
            active[channel] = -active[channel];
            _reloadTextSetter(() {});
          },
          child: Text('${(active[channel] == 1)? "订阅 ":"取消订阅"}'),

          style: ButtonStyle(
              textStyle: MaterialStateProperty.all(TextStyle(fontSize: 14)),
              backgroundColor:MaterialStateProperty.all((active[channel] == 1)?Colors.blueAccent:Colors.redAccent),
        ),
      )
    );
  }
  void _showDialog() {
    Size size = MediaQuery.of(context).size;
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          // var list =[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];
          return StatefulBuilder(builder: (context,  StateSetter stateSetter) {
            _reloadTextSetter = stateSetter;
            return Dialog(
              insetPadding: EdgeInsets.symmetric(vertical: 100, horizontal: 10),
              backgroundColor: Colors.transparent,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 50,
                          color: Colors.blueAccent,
                          child: Center(
                            child: Text(
                              "订阅参数",
                              style: TextStyle(color: Colors.white, fontSize: 24),
                            ),
                          ),
                        ),
                        Expanded(child: ListView.separated(
                          itemCount: sublist.length,
                          itemBuilder: (BuildContext context, int index){
                            return ListTile(title: Text(sublist[index]),
                              trailing:
                              _buildButton(index),);
                          },
                          separatorBuilder: (BuildContext context, int index) => const Divider(height: 0,thickness: 1),
                        )
                        ),
                        Container(
                          padding:
                          EdgeInsets.symmetric(horizontal: 100, vertical: 10),
                          child: FlatButton(
                              color: Colors.blueAccent,
                              textColor: Colors.white,
                              onPressed: () {
                                Navigator.of(context).pop();
                                //active的值存储
                                subInfoSave();
                              },
                              child: Text("返回")),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );});

        });
  }

    void initData() {
    active = List.filled(20, 1);
    activeWrite = List.filled(20,'1');
    list1=['EPICS_1','EPICS_2','EPICS_3','EPICS_4','EPICS_5'];
    list2=['MDSplus_1','MDSplus_2','MDSplus_3','MDSplus_4',
      'MDSplus_5','MDSplus_6','MDSplus_7','MDSplus_8','MDSplus_9','MDSplus_10'];
    list3=['LOG_1','LOG_2','LOG_3','LOG_4','LOG_5'];
    pageData = [{"title":"EPICS系统", "content":epicsList},
      {"title":"MDSplus信号", "content":mdsPlusList},
      {"title":"EPICS日志", "content":logList}];
    sublist = list1+list2+list3;
    bool isContainKey = SpUtil.haveKey(uid!)!;
    if(isContainKey){
      subInfoRead();}    //读取用于保存订阅信息的active值

  }

  void updateMessage(list1,list2,list3){
    pageData[0]["name"] = {"title":"EPICS系统", "content":list1};
    pageData[1]["name"] = {"title":"MDSplus信号", "content":list2};
    pageData[2]["name"] = {"title":"EPICS日志", "content":list3};
   }

  void WsConnect(){
    _channel = IOWebSocketChannel.connect(Uri.parse('ws://172.25.6.235:9000/ws'),headers: {"Origin":"*"}
        );
    print("WebSocket连接成功");
  }

  void onListen(){
    _heartCheck();
    _channel.stream.asBroadcastStream().listen((message) {
      dataHandle(message);
      setState(() {
      });
    },onDone: () {
      print("WebSocket连接断开");
      _reConnect();
    });
  }
  /// 发送心跳包
  void _heartCheck() {
    Future.delayed(Duration(seconds: 300)).then((value) {
      _channel.sink.add(jsonEncode({"action":"HEART"}));
      _heartCheck();
    });
  }
  ///断线重连
  void _reConnect(){
    print("WebSocket重连中...");
    if(lockReconnect) {return;}
    lockReconnect = true;
    Future.delayed(Duration(seconds: 3)).then((value) {
      WsConnect();
      //1.按钮颜色重新渲染  2.重新订阅
      lockReconnect = false;
    });
  }

  void dataHandle(message){
    Map params = json.decode(message);
    if(params.length >1){   //非心跳返回值
      print(message);
      if(params["data"]!=null && list1.contains(params["channel"])){
        epicsList.add(params["data"]);
      }else if(params["data"]!=null && list2.contains(params["channel"])){
        mdsPlusList.add(params["data"]);
      }else if(params["data"]!=null && list3.contains(params["channel"])){
        logList.add(params["data"]);}
      updateMessage(epicsList,mdsPlusList,logList);
    }else{print(params["action"]);}
  }

  void sendHandle(message) {
    _channel.sink.add(message);
  }

  void subInfoSave(){
    //active格式转换
    for(int i=0;i<active.length;i++){
      activeWrite[i] = active[i].toString();
    }
    //active存储
    // await prefs.setStringList(uid!, activeWrite);
    SpUtil.putStringList(uid!, activeWrite);
  }

  subInfoRead(){
    activeRead = SpUtil.getStringList(uid!)!;
    print(activeRead);
    print(activeRead.indexOf('-1'));
    for(int i=0;i<activeRead.length;i++){
      active[i] = int.parse(activeRead[i]);
    }
    for(int i=0;i<activeRead.length;i++){     //重新订阅
      if(activeRead[i] =='-1'){sub(sublist[i]);}

      return active;
    }
  }
  void sub(channel) {
    sendHandle(jsonEncode(
          {
            "action": "SUBSCRIBE",
            "channel":"$channel",
            "data":""
          },
        ));
    print(channel+' subscribe succeed');
  }

  void unsub(channel) {
    sendHandle(jsonEncode(
          {
            "action": "UNSUBSCRIBE",
            "channel":"$channel",
            "data":""
          },
        ));
    print(channel+' unsubscribe succeed');
  }
}

