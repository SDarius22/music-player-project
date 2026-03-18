import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';

class LibrarySettings extends StatefulWidget {
  static Route<dynamic> route({
    required AbstractAppStateProvider abstractAppStateProvider,
    bool backButton = true,
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return LibrarySettings(
          abstractAppStateProvider: abstractAppStateProvider,
          backButton: backButton,
        );
      },
    );
  }

  final bool backButton;
  final AbstractAppStateProvider abstractAppStateProvider;

  const LibrarySettings({
    super.key,
    required this.backButton,
    required this.abstractAppStateProvider,
  });

  @override
  State<LibrarySettings> createState() => _LibrarySettingsState();
}

class _LibrarySettingsLayout {
  final double width;
  final double height;

  const _LibrarySettingsLayout({required this.width, required this.height});

  double get headerHeight => height * 0.065;

  double get headerIconSize => 20.0;

  double get actionIconSize => 28.0;

  double get bottomPadding => height * 0.01;

  double get horizontalPadding => width * 0.05;

  double get headerHorizontalPadding => width * 0.01;

  double get emptyStateSpacing => height * 0.025;

  double get emptyStateButtonWidth => width * 0.1;

  double get emptyStateButtonHeight => height * 0.06;

  BorderRadius get buttonBorderRadius => BorderRadius.circular(height * 0.015);
}

class _LibrarySettingsState extends State<LibrarySettings> {
  AbstractAppStateProvider get _provider => widget.abstractAppStateProvider;

  List<String> get _songPlaces => _provider.appSettings.songPlaces;

  List<int> get _includeSubfolders =>
      _provider.appSettings.songPlaceIncludeSubfolders;

  @override
  void initState() {
    super.initState();
    _normalizeSettingsListsIfNeeded();
  }

  void _persistAndRebuild() {
    _provider.updateAppSettings();
    setState(() {});
  }

  void _normalizeSettingsListsIfNeeded() {
    final places = List<String>.from(_songPlaces);
    final includes = List<int>.from(_includeSubfolders);

    if (includes.length < places.length) {
      includes.addAll(List<int>.filled(places.length - includes.length, 1));
    } else if (includes.length > places.length) {
      includes.removeRange(places.length, includes.length);
    }

    if (places.isEmpty) {
      _provider.appSettings.mainSongPlace = '';
    } else if (!_provider.appSettings.songPlaces.contains(
      _provider.appSettings.mainSongPlace,
    )) {
      _provider.appSettings.mainSongPlace = places.first;
    }

    if (places.length != _songPlaces.length ||
        includes.length != _includeSubfolders.length ||
        !_listsEqual(includes, _includeSubfolders)) {
      _provider.appSettings.songPlaces = places;
      _provider.appSettings.songPlaceIncludeSubfolders = includes;
      _provider.updateAppSettings();
    }
  }

  bool _listsEqual(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _pickAndSetFirstFolder() async {
    final chosen = await FilePicker.platform.getDirectoryPath() ?? '';
    if (chosen.isEmpty) return;

    _provider.appSettings.songPlaces = [chosen];
    _provider.appSettings.mainSongPlace = chosen;
    _provider.appSettings.songPlaceIncludeSubfolders = [1];
    _persistAndRebuild();
  }

  Future<void> _pickAndAddFolder() async {
    final chosen = await FilePicker.platform.getDirectoryPath() ?? '';
    if (chosen.isEmpty) return;

    _provider.appSettings.songPlaces = List<String>.from(_songPlaces)
      ..add(chosen);
    _provider.appSettings.songPlaceIncludeSubfolders = List<int>.from(
      _includeSubfolders,
    )..add(1);

    if (_provider.appSettings.mainSongPlace.isEmpty) {
      _provider.appSettings.mainSongPlace = chosen;
    }

    _persistAndRebuild();
  }

  void _setMainFolder(int index) {
    if (_songPlaces.length <= 1) return;
    if (index < 0 || index >= _songPlaces.length) return;

    _provider.appSettings.mainSongPlace = _songPlaces[index];
    _persistAndRebuild();
  }

  void _toggleIncludeSubfolders(int index) {
    if (index < 0 || index >= _songPlaces.length) return;
    _normalizeSettingsListsIfNeeded();

    final updated = List<int>.from(_includeSubfolders);
    updated[index] = updated[index] == 1 ? 0 : 1;
    _provider.appSettings.songPlaceIncludeSubfolders = updated;
    _persistAndRebuild();
  }

  void _removeFolder(int index) {
    if (index < 0 || index >= _songPlaces.length) return;

    final removed = _songPlaces[index];

    _provider.appSettings.songPlaces = List<String>.from(_songPlaces)
      ..removeAt(index);
    _provider.appSettings.songPlaceIncludeSubfolders = List<int>.from(
      _includeSubfolders,
    )..removeAt(index);

    if (_provider.appSettings.mainSongPlace == removed) {
      _provider.appSettings.mainSongPlace =
          _provider.appSettings.songPlaces.isNotEmpty
              ? _provider.appSettings.songPlaces.first
              : '';
    }

    _persistAndRebuild();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final layout = _LibrarySettingsLayout(
      width: media.width,
      height: media.height,
    );

    final isEmpty = _songPlaces.isEmpty;

    return GlassScaffold(
      body: Padding(
        padding: EdgeInsets.only(bottom: layout.bottomPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeader(context, layout),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                child: Center(
                  child:
                      isEmpty
                          ? _buildEmptyState(context, layout)
                          : _buildFoldersTable(context, layout),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _LibrarySettingsLayout layout) {
    return Container(
      height: widget.backButton ? layout.headerHeight : 0,
      width: layout.width,
      padding: EdgeInsets.symmetric(horizontal: layout.headerHorizontalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.backButton)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                FluentIcons.back,
                size: layout.headerIconSize,
                color: Colors.white,
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, _LibrarySettingsLayout layout) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Add music to your library by choosing a folder below:',
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        SizedBox(height: layout.emptyStateSpacing),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: layout.emptyStateButtonWidth,
          height: layout.emptyStateButtonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: Colors.white,
              backgroundColor: Colors.grey.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: layout.buttonBorderRadius,
              ),
            ),
            onPressed: _pickAndSetFirstFolder,
            child: Icon(
              FluentIcons.folder,
              color: Colors.white,
              size: layout.actionIconSize,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoldersTable(
    BuildContext context,
    _LibrarySettingsLayout layout,
  ) {
    _normalizeSettingsListsIfNeeded();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      child: DataTable(
        columns: [
          DataColumn(
            label: Text(
              'Folder',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Main',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          DataColumn(
            headingRowAlignment: MainAxisAlignment.center,
            label: Text(
              'Include subfolders',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              '',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
        rows: [
          for (var i = 0; i < _songPlaces.length; i++)
            _buildFolderRow(layout, i),
          _buildAddFolderRow(layout),
        ],
      ),
    );
  }

  DataRow _buildFolderRow(_LibrarySettingsLayout layout, int index) {
    final folder = _songPlaces[index];

    final isMain = _provider.appSettings.mainSongPlace == folder;
    final includeSubfolders =
        index < _includeSubfolders.length && _includeSubfolders[index] == 1;

    return DataRow(
      cells: [
        DataCell(
          Text(
            folder,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
          ),
        ),
        DataCell(
          IconButton(
            icon: Icon(
              isMain ? FluentIcons.checkCircleOn : FluentIcons.checkCircleOff,
              color: Colors.white,
              size: layout.actionIconSize,
            ),
            onPressed:
                _songPlaces.length <= 1 ? null : () => _setMainFolder(index),
          ),
        ),
        DataCell(
          IconButton(
            icon: Icon(
              includeSubfolders
                  ? FluentIcons.checkCircleOn
                  : FluentIcons.checkCircleOff,
              color: Colors.white,
              size: layout.actionIconSize,
            ),
            onPressed: () => _toggleIncludeSubfolders(index),
          ),
        ),
        DataCell(
          IconButton(
            icon: Icon(
              FluentIcons.trash,
              color: Colors.red,
              size: layout.actionIconSize,
            ),
            onPressed: () => _removeFolder(index),
          ),
        ),
      ],
    );
  }

  DataRow _buildAddFolderRow(_LibrarySettingsLayout layout) {
    return DataRow(
      cells: [
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        DataCell(
          IconButton(
            onPressed: _pickAndAddFolder,
            tooltip: 'Add Another Folder',
            icon: Icon(
              FluentIcons.folderAdd,
              color: Colors.white,
              size: layout.actionIconSize,
            ),
          ),
        ),
      ],
    );
  }
}
