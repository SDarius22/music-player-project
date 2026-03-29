package com.example.musicplayerbackend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

@Slf4j
@Service
@RequiredArgsConstructor
public class PeerTrackingService {

    private final RedisTemplate<String, String> redisTemplate;
    private final ObjectMapper objectMapper;

    private static final String CHUNKS_KEY_PREFIX = "peer:chunks:";
    private static final String SONGS_KEY_PREFIX = "peer:songs:";

    public void registerPeerChunks(Integer songId, String peerId, Set<Integer> chunkIndices) {
        try {
            String chunksKey = CHUNKS_KEY_PREFIX + songId;
            String songsKey = SONGS_KEY_PREFIX + peerId;

            String existing = (String) redisTemplate.opsForHash().get(chunksKey, peerId);
            Set<Integer> merged = new HashSet<>(chunkIndices);
            if (existing != null) {
                Set<Integer> prev = objectMapper.readValue(existing, new TypeReference<>() {});
                merged.addAll(prev);
            }

            redisTemplate.opsForHash().put(chunksKey, peerId, objectMapper.writeValueAsString(merged));
            redisTemplate.opsForSet().add(songsKey, String.valueOf(songId));

            log.info("[PEER_TRACKING] Registered {} chunk(s) for peer={}, songId={} (total cached: {})",
                    chunkIndices.size(), peerId, songId, merged.size());
        } catch (Exception e) {
            log.error("[PEER_TRACKING] Failed to register peer chunks: {}", e.getMessage());
        }
    }

    public void unregisterPeer(String peerId) {
        try {
            String songsKey = SONGS_KEY_PREFIX + peerId;
            Set<String> songIds = redisTemplate.opsForSet().members(songsKey);

            if (songIds != null) {
                for (String songId : songIds) {
                    redisTemplate.opsForHash().delete(CHUNKS_KEY_PREFIX + songId, peerId);
                }
            }
            redisTemplate.delete(songsKey);
            log.info("[PEER_TRACKING] Unregistered peer={}", peerId);
        } catch (Exception e) {
            log.error("[PEER_TRACKING] Failed to unregister peer: {}", e.getMessage());
        }
    }

    public Map<String, Set<Integer>> getPeerBufferMapsForSong(Integer songId) {
        try {
            Map<Object, Object> raw = redisTemplate.opsForHash().entries(CHUNKS_KEY_PREFIX + songId);
            if (raw.isEmpty()) {
                log.info("[PEER_TRACKING] No peers found for songId={}", songId);
                return Collections.emptyMap();
            }

            Map<String, Set<Integer>> result = new HashMap<>();
            for (Map.Entry<Object, Object> entry : raw.entrySet()) {
                Set<Integer> chunks = objectMapper.readValue((String) entry.getValue(), new TypeReference<>() {});
                result.put((String) entry.getKey(), chunks);
            }
            log.info("[PEER_TRACKING] Returning buffer map for songId={}: {} peer(s)", songId, result.size());
            return Collections.unmodifiableMap(result);
        } catch (Exception e) {
            log.error("[PEER_TRACKING] Failed to get peer buffer maps: {}", e.getMessage());
            return Collections.emptyMap();
        }
    }
}