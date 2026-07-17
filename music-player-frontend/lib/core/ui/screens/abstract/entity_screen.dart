import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/responsive_screen.dart';
import 'package:music_player_frontend/core/ui/components/scaffolds/glass_scaffold.dart';

abstract class EntityScreen<T extends QueryableProvider>
    extends ResponsiveScreen<BaseEntity> {
  final BaseEntity entity;
  final T provider;

  const EntityScreen({super.key, required this.entity, required this.provider});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: buildAppBar(context, entity),
      body: FutureBuilder<BaseEntity>(
        future: Future.delayed(
          const Duration(milliseconds: 500),
          () => context.mounted ? loadEntityData(context) : entity,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error loading data: ${snapshot.error}"));
          } else {
            final resolvedEntity = snapshot.hasData ? snapshot.data! : entity;
            return buildResponsiveBody(context, resolvedEntity);
          }
        },
      ),
    );
  }

  @override
  Widget buildCompactBody(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    return Column(
      children: [
        buildDetailsSection(context, entity, constraints),
        Expanded(child: buildContentSection(context, entity, constraints)),
      ],
    );
  }

  @override
  Widget buildExpandedBody(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: buildDetailsSection(context, entity, constraints)),
        Expanded(child: buildContentSection(context, entity, constraints)),
      ],
    );
  }

  Widget buildDetailsSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final imageSize = constraints.maxWidth * 0.35;
    final infoSpacing = constraints.maxHeight * 0.005;
    final artworkBottomPadding = constraints.maxHeight * 0.01;
    final borderRadius = BorderRadius.circular(constraints.maxHeight * 0.015);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Hero(
          tag: entity.getHash(),
          child: Container(
            height: imageSize,
            width: imageSize,
            padding: EdgeInsets.only(bottom: artworkBottomPadding),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: ImageWidget(entity: entity),
            ),
          ),
        ),
        Text(
          entity.getName(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: infoSpacing),
        Text(
          entity.getSecondaryText(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget buildContentSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  );

  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }

  Future<BaseEntity> loadEntityData(BuildContext context) async {
    try {
      final detailedEntity = await provider.fetchEntity(entity);
      return detailedEntity ?? entity;
    } catch (e) {
      debugPrint("Error fetching entity details: $e");
      return entity;
    }
  }
}
