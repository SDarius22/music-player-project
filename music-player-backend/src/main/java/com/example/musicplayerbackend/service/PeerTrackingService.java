package com.example.musicplayerbackend.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
public class PeerTrackingService {

    private final Map<Integer, Map<String, Set<Integer>>> songChunkRegistry = new ConcurrentHashMap<>();

    public void registerPeerChunks(Integer songId, String peerId, Set<Integer> chunkIndices) {
        Map<String, Set<Integer>> peerMap = songChunkRegistry
                .computeIfAbsent(songId, _ -> new ConcurrentHashMap<>());

        Set<Integer> peerChunks = peerMap
                .computeIfAbsent(peerId, _ -> ConcurrentHashMap.newKeySet());

        peerChunks.addAll(chunkIndices);
        log.info("[PEER_TRACKING] Registered {} chunk(s) for peer={}, songId={} (total cached: {})",
                chunkIndices.size(), peerId, songId, peerChunks.size());
    }

    public void unregisterPeer(String peerId) {
        songChunkRegistry.values().forEach(peerMap -> peerMap.remove(peerId));
        songChunkRegistry.entrySet().removeIf(entry -> entry.getValue().isEmpty());
        log.info("[PEER_TRACKING] Unregistered peer={}", peerId);
    }

    public Map<String, Set<Integer>> getPeerBufferMapsForSong(Integer songId) {
        Map<String, Set<Integer>> map = songChunkRegistry.get(songId);
        if (map == null) {
            log.info("[PEER_TRACKING] No peers found for songId={}", songId);
            return Collections.emptyMap();
        }
        log.info("[PEER_TRACKING] Returning buffer map for songId={}: {} peer(s)", songId, map.size());
        return Map.copyOf(map);
    }
}