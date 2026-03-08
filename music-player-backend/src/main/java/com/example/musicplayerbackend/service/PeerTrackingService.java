package com.example.musicplayerbackend.service;

import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class PeerTrackingService {

    private final Map<Integer, Map<String, Set<Integer>>> songChunkRegistry = new ConcurrentHashMap<>();

    public void registerPeerChunks(Integer songId, String peerId, Set<Integer> chunkIndices) {
        Map<String, Set<Integer>> peerMap = songChunkRegistry
                .computeIfAbsent(songId, _ -> new ConcurrentHashMap<>());

        Set<Integer> peerChunks = peerMap
                .computeIfAbsent(peerId, _ -> ConcurrentHashMap.newKeySet());

        peerChunks.addAll(chunkIndices);
    }

    public void unregisterPeer(String peerId) {
        songChunkRegistry.values().forEach(peerMap -> peerMap.remove(peerId));
        songChunkRegistry.entrySet().removeIf(entry -> entry.getValue().isEmpty());
    }

    public Map<String, Set<Integer>> getPeerBufferMapsForSong(Integer songId) {
        Map<String, Set<Integer>> map = songChunkRegistry.get(songId);
        if (map == null) {
            return Collections.emptyMap();
        }
        return Map.copyOf(map);
    }
}