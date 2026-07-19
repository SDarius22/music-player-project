import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/ui/components/app_layout.dart';

void main() {
  test('4K layout spacing is capped instead of scaling indefinitely', () {
    expect(AppLayout.pageInset(3840, mobile: false), 36);
    expect(AppLayout.contentInset(3840), 32);
    expect(AppLayout.drawerWidth(3840, expanded: true), 320);
    expect(AppLayout.homeCardHeight(3840, wide: false), 280);
    expect(
      AppLayout.mainScaffoldPadding(const Size(3840, 2160), mobile: false),
      const EdgeInsets.all(36),
    );
  });

  test('desktop and mobile spacing retain practical minimums', () {
    expect(AppLayout.pageInset(1200, mobile: false), 18);
    expect(AppLayout.pageInset(360, mobile: true), 14.4);
    expect(AppLayout.drawerWidth(1200, expanded: true), 220);
  });
}
