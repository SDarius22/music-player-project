package com.example.music_player_frontend

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Extends [AudioServiceActivity] so the launched activity keeps the exact
 * audio_service behavior the manifest previously referenced directly, while
 * allowing the app to register its own platform channels.
 */
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!flutterEngine.plugins.has(LocalSourceReaderPlugin::class.java)) {
            flutterEngine.plugins.add(LocalSourceReaderPlugin())
        }
    }
}
