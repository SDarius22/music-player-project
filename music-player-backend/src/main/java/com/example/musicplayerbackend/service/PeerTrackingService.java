package com.example.musicplayerbackend.service;

import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;

@Service
public class PeerTrackingService {

    private final Map<Integer, Map<String, Set<Integer>>> songChunkRegistry = new ConcurrentHashMap<>();

    public void registerPeerChunks(Integer songId, String peerId, Set<Integer> chunkIndices) {
        songChunkRegistry
                .computeIfAbsent(songId, k -> new ConcurrentHashMap<>())
                .merge(peerId, new CopyOnWriteArraySet<>(chunkIndices), (existing, newChunks) -> {
                    existing.addAll(newChunks);
                    return existing;
                });
    }

    public void unregisterPeer(String peerId) {
        songChunkRegistry.values().forEach(peerMap -> peerMap.remove(peerId));
        songChunkRegistry.entrySet().removeIf(entry -> entry.getValue().isEmpty());
    }

    public Map<String, Set<Integer>> getPeerBufferMapsForSong(Integer songId) {
        return songChunkRegistry.getOrDefault(songId, Map.of());
    }
}