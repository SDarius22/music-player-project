package com.example.musicplayerbackend.service;

import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;

@Service
public class PeerTrackingService {

    // Maps a Song ID to a Set of active WebSocket Session IDs (Peers) that have the song cached
    private final Map<Integer, Set<String>> songCacheRegistry = new ConcurrentHashMap<>();

    public void registerPeerCache(Integer songId, String peerId) {
        songCacheRegistry.computeIfAbsent(songId, k -> new CopyOnWriteArraySet<>()).add(peerId);
    }

    public void unregisterPeer(String peerId) {
        // Remove the disconnected peer from all song registries
        songCacheRegistry.values().forEach(peers -> peers.remove(peerId));
        // Cleanup empty sets to prevent memory leaks
        songCacheRegistry.entrySet().removeIf(entry -> entry.getValue().isEmpty());
    }

    public Set<String> getAvailablePeersForSong(Integer songId) {
        return songCacheRegistry.getOrDefault(songId, Set.of());
    }
}