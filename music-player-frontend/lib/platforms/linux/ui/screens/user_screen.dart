// import 'dart:async';
// import 'dart:convert';
//
// import 'package:http/http.dart' as http;
//
// import 'package:flutter/material.dart';
// import 'package:musicplayer/utils/fluenticons/fluenticons.dart';
// import 'package:musicplayer/controller/online_controller.dart';
// import 'package:musicplayer/controller/settings_controller.dart';
// import 'package:flutter_svg/flutter_svg.dart';
//
// class UserScreen extends StatefulWidget {
//   const UserScreen({super.key});
//   @override
//   State<UserScreen> createState() => _UserScreenState();
// }
//
// class _UserScreenState extends State<UserScreen> {
//   String email = '';
//   String password = '';
//   bool login = true;
//
//   late Future loading;
//
//   @override
//   void initState() {
//     super.initState();
//     loading = loadingFuture();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final oc = OnlineController();
//     var width = MediaQuery.of(context).size.width;
//     var height = MediaQuery.of(context).size.height;
//     var boldSize = height * 0.025;
//     var normalSize = height * 0.02;
//     var smallSize = height * 0.015;
//     return Scaffold(
//       body: Container(
//           width: width,
//           height: height,
//           padding: EdgeInsets.only(
//               top: height * 0.02,
//               left: width * 0.01,
//               right: width * 0.01,
//               bottom: height * 0.02
//           ),
//           alignment: Alignment.center,
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               IconButton(
//                 onPressed: (){
//                   debugPrint("Back");
//                   Navigator.pop(context);
//                 },
//                 icon: Icon(
//                   FluentIcons.back,
//                   size: height * 0.02,
//                   color: Colors.white,
//                 ),
//               ),
//               Container(
//                 width: width * 0.85,
//                 padding: EdgeInsets.only(
//                   top: height * 0.05,
//                   bottom: height * 0.125,
//                   left: width * 0.25,
//                   right: width * 0.25,
//                 ),
//                 alignment: Alignment.center,
//                 child: FutureBuilder(
//                     future: loading,
//                     builder: (context, snapshot){
//                       if (snapshot.connectionState == ConnectionState.waiting) {
//                         return const Center(
//                           child: CircularProgressIndicator(
//                             valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                           ),
//                         );
//                       }
//                       return OnlineController.loggedInNotifier.value ?
//                       Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Text(
//                             "Logged in as ${SettingsController.email}",
//                             style: TextStyle(
//                               fontSize: boldSize,
//                               color: Colors.white,
//                             ),
//                           ),
//                           SizedBox(
//                             height: height * 0.05,
//                           ),
//                           Container(
//                             width: width,
//                             height: height * 0.075,
//                             child: ElevatedButton(
//                               onPressed: (){
//                                 debugPrint("Logout");
//                                 SettingsController.email = '';
//                                 SettingsController.password = '';
//                                 OnlineController.loggedInNotifier.value = false;
//                                 SettingsController.mongoID = '';
//                                 // oc.settingsBox.put(oc.settings);
//                                 login = true;
//                                 setState(() {
//                                   loading = loadingFuture();
//                                 });
//                               },
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Text(
//                                     "Logout",
//                                     style: TextStyle(
//                                       fontSize: normalSize,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ],
//                       ) :
//                       snapshot.data ?
//                       Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Container(
//                             width: width,
//                             height: height * 0.075,
//                             child: ElevatedButton(
//                               onPressed: (){
//                                 debugPrint("Login with Google");
//                               },
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Text(
//                                     "Login with Google",
//                                     style: TextStyle(
//                                       fontSize: normalSize,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                   const Spacer(),
//                                   SvgPicture.asset(
//                                     'assets/google.svg',
//                                     width: height * 0.03,
//                                     height: height * 0.03,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: height * 0.05,
//                           ),
//                           Container(
//                             height: 1,
//                             color: Colors.grey.shade400,
//                           ),
//                           SizedBox(
//                             height: height * 0.05,
//                           ),
//                           Container(
//                             width: width,
//                             height: height * 0.075,
//                             child: TextFormField(
//                               initialValue: email,
//                               onChanged: (value){
//                                 email = value;
//                               },
//                               cursorColor: Colors.white,
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: normalSize,
//                               ),
//                               decoration: InputDecoration(
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(width * 0.02),
//                                   borderSide: const BorderSide(
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                                 contentPadding: EdgeInsets.only(
//                                   left: width * 0.012,
//                                   right: width * 0.012,
//                                 ),
//                                 floatingLabelBehavior: FloatingLabelBehavior.auto,
//                                 labelStyle: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: normalSize,
//                                 ),
//                                 labelText: 'Email',
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: height * 0.01,
//                           ),
//                           Container(
//                             width: width,
//                             height: height * 0.075,
//                             child: TextFormField(
//                               initialValue: password,
//                               onChanged: (value){
//                                 password = value;
//                               },
//                               cursorColor: Colors.white,
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: normalSize,
//                               ),
//                               decoration: InputDecoration(
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(width * 0.02),
//                                   borderSide: const BorderSide(
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                                 contentPadding: EdgeInsets.only(
//                                   left: width * 0.012,
//                                   right: width * 0.012,
//                                 ),
//                                 floatingLabelBehavior: FloatingLabelBehavior.auto,
//                                 labelStyle: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: normalSize,
//                                 ),
//                                 labelText: 'Password',
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: height * 0.01,
//                           ),
//                           Container(
//                             width: width,
//                             child: Row(
//                               children: [
//                                 TextButton(onPressed: (){
//                                   setState(() {
//                                     email = '';
//                                     password = '';
//                                     login = false;
//                                     loading = loadingFuture();
//                                   });
//                                 }, child: Text(
//                                   "Don't have an account?",
//                                   style: TextStyle(
//                                     decoration: TextDecoration.underline,
//                                     fontSize: normalSize,
//                                     color: Colors.white,
//                                   ),
//                                 )),
//                                 const Spacer(),
//                                 ElevatedButton(
//                                   style: ElevatedButton.styleFrom(
//                                     padding: const EdgeInsets.all(0),
//                                     foregroundColor: Colors.white, backgroundColor: Colors.grey.shade900,
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(10.0),
//                                     ),
//                                   ),
//                                   onPressed: () async {
//                                     SettingsController.email = email;
//                                     SettingsController.password = password;
//                                     await oc.loginUser();
//                                     setState(() {
//                                       loading = loadingFuture();
//                                     });
//                                   },
//                                   child: Icon(FluentIcons.forward, color: Colors.white, size: height * 0.03,),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ) :
//                       Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Container(
//                             width: width,
//                             height: height * 0.075,
//                             alignment: Alignment.center,
//                             child: Text(
//                               "Create an account",
//                               style: TextStyle(
//                                 fontSize: boldSize,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: height * 0.025,
//                           ),
//                           Container(
//                             width: width,
//                             height: height * 0.075,
//                             child: ElevatedButton(
//                               onPressed: (){
//                                 debugPrint("Register with Google");
//                               },
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Text(
//                                     "Register with Google",
//                                     style: TextStyle(
//                                       fontSize: normalSize,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                   const Spacer(),
//                                   SvgPicture.asset(
//                                     'assets/google.svg',
//                                     width: height * 0.03,
//                                     height: height * 0.03,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: height * 0.05,
//                           ),
//                           Container(
//                             height: 1,
//                             color: Colors.grey.shade400,
//                           ),
//                           SizedBox(
//                             height: height * 0.05,
//                           ),
//                           Container(
//                             width: width,
//                             height: height * 0.075,
//                             child: TextFormField(
//                               initialValue: email,
//                               onChanged: (value){
//                                 email = value;
//                               },
//                               cursorColor: Colors.white,
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: normalSize,
//                               ),
//                               decoration: InputDecoration(
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(width * 0.02),
//                                   borderSide: const BorderSide(
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                                 contentPadding: EdgeInsets.only(
//                                   left: width * 0.012,
//                                   right: width * 0.012,
//                                 ),
//                                 floatingLabelBehavior: FloatingLabelBehavior.auto,
//                                 labelStyle: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: normalSize,
//                                 ),
//                                 labelText: 'Email',
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: height * 0.01,
//                           ),
//                           Container(
//                             width: width,
//                             height: height * 0.075,
//                             child: TextFormField(
//                               initialValue: password,
//                               onChanged: (value){
//                                 password = value;
//                               },
//                               cursorColor: Colors.white,
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: normalSize,
//                               ),
//                               decoration: InputDecoration(
//                                 border: OutlineInputBorder(
//                                   borderRadius: BorderRadius.circular(width * 0.02),
//                                   borderSide: const BorderSide(
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                                 contentPadding: EdgeInsets.only(
//                                   left: width * 0.012,
//                                   right: width * 0.012,
//                                 ),
//                                 floatingLabelBehavior: FloatingLabelBehavior.auto,
//                                 labelStyle: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: normalSize,
//                                 ),
//                                 labelText: 'Password',
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: height * 0.005,
//                           ),
//                           Container(
//                             width: width,
//                             height: height * 0.05,
//                             alignment: Alignment.center,
//                             child: Text(
//                               "By creating an account, you agree to our Terms of Service and Privacy Policy",
//                               style: TextStyle(
//                                 fontSize: smallSize,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             height: height * 0.01,
//                           ),
//                           Container(
//                             width: width,
//                             child: Row(
//                               children: [
//                                 TextButton(onPressed: (){
//                                   setState(() {
//                                     email = '';
//                                     password = '';
//                                     login = true;
//                                     loading = loadingFuture();
//                                   });
//                                 }, child: Text(
//                                   "Already have an account?",
//                                   style: TextStyle(
//                                     decoration: TextDecoration.underline,
//                                     fontSize: normalSize,
//                                     color: Colors.white,
//                                   ),
//                                 )),
//                                 const Spacer(),
//                                 TextButton(
//                                   onPressed: () async {
//
//
//                                   }, child: Text(
//                                   "Create Account",
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//
//                         ],
//                       );
//                     }
//                 ),
//               ),
//               SizedBox(
//                 width: width * 0.02,
//               ),
//             ],
//           )
//       ),
//     );
//   }
//
//   Future fetchData() async {
//     var uri = Uri.parse('http://localhost:8000/api/get-user');
//     var request = http.Request('GET', uri)
//       ..headers.addAll({
//         'Content-Type': 'application/json',
//       })
//       ..body = jsonEncode({
//         'email': email,
//         'password': password,
//       });
//     var response = await request.send();
//     debugPrint(response.statusCode.toString());
//     debugPrint(await response.stream.bytesToString());
//     return response.statusCode;
//   }
//
//   Future<bool> loadingFuture() async {
//     await Future.delayed(const Duration(milliseconds: 500));
//     return login;
//   }
// }