// import 'dart:convert';
//
// import 'package:flutter/cupertino.dart';
// import 'package:http/http.dart' as http;
//
// class OnlineController{
//   static final OnlineController _instance = OnlineController._internal();
//
//   factory OnlineController() => _instance;
//
//   OnlineController._internal();
//
//   static ValueNotifier<bool> loggedInNotifier = ValueNotifier<bool>(false);
//   static ValueNotifier<bool> downloadNotifier = ValueNotifier<bool>(false);
//
//
//   Future<void> loginUser() async {
//     // debugPrint("Log in");
//     // var data = "{'email': '${SettingsController.email}', 'password': '${SettingsController.password}'}";
//     // var encryptedData = await encryptData(data);
//     // debugPrint(encryptedData);
//     // var uri = Uri.parse('http://localhost:8000/api/get-user');
//     // var request = http.Request('GET', uri)
//     //   ..headers.addAll({
//     //     'Content-Type': 'application/json',
//     //   })
//     //   ..body = jsonEncode({
//     //     'data': encryptedData,
//     //   });
//     // var response = await request.send();
//     // if (response.statusCode == 200) {
//     //   debugPrint("Success");
//     //   String body = await response.stream.bytesToString();
//     //   Map<String, dynamic> data = jsonDecode(body);
//     //   if (data['message'] == "Not premium user") {
//     //     SettingsController.mongoID = data['id'];
//     //   } else {
//     //     // SettingsController.fromMap(data);
//     //   }
//     //   // loggedInNotifier.value = true;
//     //   // settingsBox.put(settings);
//     // } else {
//     //   debugPrint("Failed");
//     //   debugPrint(response.statusCode.toString());
//     //   debugPrint(response.stream.bytesToString().toString());
//     // }
//   }
//
//   Future<void> registerUser() async {
//     // debugPrint("Register user");
//     // var data = "{'email': '${SettingsController.email}',"
//     //     "'password': '${SettingsController.password}',"
//     //     "'index': ${SettingsController.index},"
//     //     "'deviceList': ${SettingsController.deviceList},"
//     //     "'primaryDevice': ${SettingsController.primaryDevice},"
//     //     "'firstTime': ${SettingsController.firstTime},"
//     //     "'systemTray': ${SettingsController.systemTray},"
//     //     "'fullClose': ${SettingsController.fullClose},"
//     //     "'appNotifications': ${SettingsController.appNotifications},"
//     //     "'deezerARL': ${SettingsController.deezerARL},"
//     //     "'queueAdd': ${SettingsController.queueAdd},"
//     //     "'queuePlay': ${SettingsController.queuePlay},"
//     //     "'queue': ${SettingsController.queue},"
//     //     "'missingSongs': ${SettingsController.missingSongs}}";
//     //
//     // var encryptedData = await encryptData(data);
//     // debugPrint(encryptedData);
//     // var uri = Uri.parse('http://localhost:8000/api/upload-user');
//     // var request = http.Request('POST', uri)
//     //   ..headers.addAll({
//     //     'Content-Type': 'application/json',
//     //   })
//     //   ..body = jsonEncode({
//     //     'data': encryptedData,
//     //   });
//     // var response = await request.send();
//     // if (response.statusCode == 201) {
//     //   debugPrint("Success");
//     //   String body = await response.stream.bytesToString();
//     //   Map<String, dynamic> data = jsonDecode(body);
//     //   SettingsController.mongoID = data['id'];
//     //   // loggedInNotifier.value = true;
//     //   // settingsBox.put(settings);
//     // } else {
//     //   debugPrint("Failed");
//     //   debugPrint(response.statusCode.toString());
//     //   debugPrint(await response.stream.bytesToString()..toString());
//     // }
//   }
//
//   static Future<dynamic> searchDeezer(String searchValue) async {
//     if (searchValue.isEmpty) {
//       return [];
//     }
//     // final Map<String, String> cookies = {'arl': SettingsController.deezerARL};
//     String searchUrl = 'https://api.deezer.com/search?q=$searchValue&limit=56&index=0&output=json';
//     debugPrint(searchUrl);
//
//     // final http.Response getResponse = await http.get(Uri.parse(searchUrl), headers: {
//     //   'Cookie': 'arl=${cookies['arl']}',
//     // });
//
//     final http.Response getResponse = await http.get(Uri.parse(searchUrl));
//
//     final Map<String, dynamic> getResponseJson = jsonDecode(getResponse.body);
//     return (getResponseJson['data']);
//   }
//
//   static Future<List<String>> searchLyrics(String title, String artist, String album) async {
//     String url = 'https://darius-tech.pro/api/lyrics/$title/$artist/$album';
//     debugPrint("Searching lyrics for $title by $artist");
//     //print(url);
//     String plainLyric = "";
//     String syncedLyric = "";
//
//     final http.Response getResponse = await http.get(Uri.parse(url));
//
//     final Map<String, dynamic> getResponseJson = jsonDecode(utf8.decode(getResponse.bodyBytes));
//
//     //print(getResponseJson);
//
//     plainLyric = getResponseJson['plain_lyrics'];
//     syncedLyric = getResponseJson['synced_lyrics'];
//
//     return [plainLyric, syncedLyric];
//   }
//
//   Future<void> updateUser() async {
//     // debugPrint("Update user");
//     // var data = SettingsController.toMap().toString();
//     // var encryptedData = await encryptData(data);
//     // debugPrint(encryptedData);
//     // var uri = Uri.parse('http://localhost:8000/api/update-user');
//     // var request = http.Request('POST', uri)
//     //   ..headers.addAll({
//     //     'Content-Type': 'application/json',
//     //   })
//     //   ..body = jsonEncode({
//     //     'data': encryptedData,
//     //   });
//     // var response = await request.send();
//     // debugPrint(response.statusCode);
//     // debugPrint(await response.stream.bytesToString());
//   }
// }