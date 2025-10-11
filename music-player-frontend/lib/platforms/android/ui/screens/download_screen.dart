// import 'dart:io';
// import 'dart:typed_data';
//
// import 'package:audiotags/audiotags.dart';
// import 'package:musicplayer/utils/fluenticons/fluenticons.dart';
// import 'package:flutter/material.dart';
// import 'package:musicplayer/controller/app_manager.dart';
// import 'package:musicplayer/controller/online_controller.dart';
// import 'package:musicplayer/controller/settings_controller.dart';
// import 'package:musicplayer/interface/widgets/image_widget.dart';
// import 'dart:async';
// import 'package:http/http.dart' as http;
//
// class Download extends StatefulWidget{
//   const Download({super.key});
//
//   @override
//   State<Download> createState() => _DownloadState();
// }
//
//
// class _DownloadState extends State<Download>{
//   FocusNode searchNode = FocusNode();
//
//   Timer? _debounce;
//
//   late Future downloadFuture;
//
//   @override
//   void initState(){
//     super.initState();
//     downloadFuture = OnlineController.searchDeezer('');
//   }
//
//   _onSearchChanged(String query) {
//     if (_debounce?.isActive ?? false) _debounce?.cancel();
//     _debounce = Timer(const Duration(milliseconds: 1000), () {
//       setState(() {
//         downloadFuture = OnlineController.searchDeezer(query);
//       });
//     });
//   }
//
//
//   @override
//   void dispose() {
//     _debounce?.cancel();
//     super.dispose();
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final am = AppManager();
//     var width = MediaQuery.of(context).size.width;
//     var height = MediaQuery.of(context).size.height;
//     // var boldSize = height * 0.025;
//     var normalSize = height * 0.02;
//     var smallSize = height * 0.015;
//     return Container(
//       padding: EdgeInsets.only(
//           top: height * 0.02,
//           left: width * 0.01,
//           right: width * 0.01,
//           bottom: height * 0.02
//       ),
//       child: Column(
//         children: [
//           Container(
//             height: height * 0.05,
//             margin: EdgeInsets.only(
//               left: width * 0.01,
//               right: width * 0.01,
//               bottom: height * 0.01,
//             ),
//             child: TextFormField(
//               initialValue: '',
//               focusNode: searchNode,
//               onChanged: _onSearchChanged,
//               cursorColor: Colors.white,
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: normalSize,
//               ),
//               decoration: InputDecoration(
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(width * 0.02),
//                     borderSide: const BorderSide(
//                       color: Colors.white,
//                     ),
//                   ),
//                   contentPadding: EdgeInsets.only(
//                     left: width * 0.01,
//                     right: width * 0.01,
//                   ),
//                   floatingLabelBehavior: FloatingLabelBehavior.never,
//                   labelStyle: TextStyle(
//                     color: Colors.white,
//                     fontSize: smallSize,
//                   ),
//                   labelText: 'Search', suffixIcon: Icon(FluentIcons.search, color: Colors.white, size: height * 0.02,)
//               ),
//             ),
//           ),
//           Expanded(
//             child: FutureBuilder(
//                 future: downloadFuture,
//                 builder: (context, snapshot){
//                   if(snapshot.hasError){
//                     return Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             FluentIcons.error,
//                             size: height * 0.1,
//                             color: Colors.red,
//                           ),
//                           Text(
//                             "Error loading songs",
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: smallSize,
//                             ),
//                           ),
//                           ElevatedButton(
//                             onPressed: (){
//                               setState(() {});
//                             },
//                             child: Text(
//                               "Retry",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: smallSize,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   }
//                   else if(snapshot.hasData){
//                     if (snapshot.data!.isEmpty){
//                       return Center(
//                         child: Text("No songs found", style: TextStyle(color: Colors.white, fontSize: smallSize),),
//                       );
//                     }
//                     List<dynamic> songs = snapshot.data;
//                     return GridView.builder(
//                       padding: EdgeInsets.only(
//                         left: width * 0.01,
//                         right: width * 0.01,
//                         top: height * 0.01,
//                         bottom: width * 0.125,
//                       ),
//                       itemCount: snapshot.data!.length,
//                       gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
//                         childAspectRatio: 0.825,
//                         maxCrossAxisExtent: width * 0.125,
//                         crossAxisSpacing: width * 0.0125,
//                         //mainAxisSpacing: width * 0.0125,
//                       ),
//                       itemBuilder: (BuildContext context, int index) {
//                         var song = songs[index];
//                         ValueNotifier<double> progress = ValueNotifier<double>(0.0);
//                         return MouseRegion(
//                           cursor: SystemMouseCursors.click,
//                           child: GestureDetector(
//                             // onTap: () async {
//                             //   debugPrint("Downloading ${song['id']}, arl: ${SettingsController.settings.deezerARL}");
//                             //   try {
//                             //     final stream = await OnlineController.instance.getSong(song['id'].toString(),
//                             //       onProgress: (received, total) {
//                             //         //debugPrint("received: $received, total: $total");
//                             //         progress.value = received / total;
//                             //       },
//                             //     );
//                             //     File file = File("${SettingsController.mainSongPlace}/${song['artist']['name']
//                             //         .toString()} - ${song['title']
//                             //         .toString()}.mp3");
//                             //     if (stream != null) {
//                             //       await file.writeAsBytes(stream.data);
//                             //       am.showNotification("Song downloaded successfully.", 3500);
//                             //     } else {
//                             //       am.showNotification("Something went wrong.", 3500);
//                             //     }
//                             //     http.Response response = await http.get(
//                             //       Uri.parse(song['album']['cover_big']),
//                             //     );
//                             //     await AudioTags.write(file.path,
//                             //       Tag(
//                             //           title: song['title'].toString(),
//                             //           trackArtist: song['artist']['name'],
//                             //           album: song['album']['title'],
//                             //           albumArtist: song['artist']['name'],
//                             //           duration: song['duration'],
//                             //           pictures: [
//                             //             Picture(
//                             //                 bytes: Uint8List.fromList(
//                             //                     response.bodyBytes),
//                             //                 mimeType: null,
//                             //                 pictureType: PictureType.other
//                             //             )
//                             //           ]
//                             //       ),
//                             //     );
//                             //   }
//                             //   catch(e){
//                             //     debugPrint(e.toString());
//                             //     if(SettingsController.deezerARL.isEmpty){
//                             //       am.showNotification("Cannot download song without a working Deezer ARL. Please add one in settings.", 3500);
//                             //     }
//                             //     else{
//                             //       am.showNotification("Something went wrong. Try again later.", 3500);
//                             //     }
//                             //   }
//                             // },
//                             child: Column(
//                               children: [
//                                 ClipRRect(
//                                   borderRadius: BorderRadius.circular(width * 0.01),
//                                   child: ImageWidget(
//                                     url: song['album']['cover_medium'],
//                                     heroTag: song['album']['cover_medium'],
//                                     hoveredChild: ValueListenableBuilder(
//                                         valueListenable: progress,
//                                         builder: (context, value, child){
//                                           return value == 0.0 ?
//                                           const Icon(
//                                               FluentIcons.download
//                                           ) :
//                                           value == 1.0 ?
//                                           const Icon(
//                                             FluentIcons.check,
//                                           ) :
//                                           CircularProgressIndicator(
//                                             value: value,
//                                           );
//                                         }
//                                     ),
//                                   ),
//                                 ),
//                                 SizedBox(
//                                   height: height * 0.005,
//                                 ),
//                                 Text(
//                                   song['title'].toString(),
//                                   maxLines: 2,
//                                   overflow: TextOverflow.ellipsis,
//                                   textAlign: TextAlign.center,
//                                   style: TextStyle(
//                                     height: 1,
//                                     color: Colors.white,
//                                     fontSize: smallSize,
//                                     fontWeight: FontWeight.normal,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//
//                         );
//
//                       },
//                     );
//                   }
//                   else{
//                     return const Center(
//                       child: CircularProgressIndicator(
//                         color: Colors.white,
//                       ),
//                     );
//                   }
//                 }
//             ),
//           ),
//
//         ],
//       ),
//     );
//   }
//
// }