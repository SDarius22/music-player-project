import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:provider/provider.dart';

class ActionsWidget extends StatefulWidget {
  const ActionsWidget({super.key});

  @override
  State<ActionsWidget> createState() => ActionsWidgetState();
}

class ActionsWidgetState extends State<ActionsWidget> {
  ValueNotifier<bool> expanded = ValueNotifier(false);

  Widget _buildContent(BuildContext context) {
    // var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    //var boldSize = height * 0.025;
    var normalSize = height * 0.02;

    return Consumer<AbstractAppStateProvider>(
      builder: (context, am, child) {
        return ValueListenableBuilder(
          valueListenable: expanded,
          builder: (context, value, child) {
            return !value
                ? am.appActions.isEmpty
                    ? const SizedBox()
                    : ListTile(
                      leading: Icon(Icons.file_download, color: Colors.white),
                      title: Text(
                        'Downloading/Uploading ${am.appActions.length} files',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: normalSize,
                        ),
                      ),
                      onTap: () {
                        expanded.value = !expanded.value;
                      },
                    )
                : AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  height: height * 0.3,
                  child: ListView.builder(
                    itemCount: am.appActions.length + 1,
                    itemBuilder: (context, index) {
                      return index == 0
                          ? IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: height * 0.015,
                            ),
                            onPressed: () {
                              expanded.value = !expanded.value;
                            },
                          )
                          : ListTile(
                            title: Text(
                              am.appActions[index],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                          );
                    },
                  ),
                );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }
}
