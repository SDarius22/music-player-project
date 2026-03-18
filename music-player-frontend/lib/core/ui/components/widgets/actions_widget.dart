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
    var height = MediaQuery.of(context).size.height;
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
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Colors.white,
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
                              size: 16,
                            ),
                            onPressed: () {
                              expanded.value = !expanded.value;
                            },
                          )
                          : ListTile(
                            title: Text(
                              am.appActions[index],
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                color: Colors.white,
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
