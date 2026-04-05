import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';

abstract class EntityScreen extends StatelessWidget {
  final BaseEntity entity;

  const EntityScreen({super.key, required this.entity});

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return GlassScaffold(
      appBar: buildAppBar(context, entity),
      body: Padding(
        padding: buildPadding(width, height),
        child: FutureBuilder(
          future: loadEntityData(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else {
              return buildBody(context, width, height);
            }
          },
        ),
      ),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }

  EdgeInsetsGeometry buildPadding(double width, double height) {
    return EdgeInsets.zero;
  }

  Widget buildBody(BuildContext context, double width, double height);

  Future<void> loadEntityData(BuildContext context) async {
    return;
  }
}
