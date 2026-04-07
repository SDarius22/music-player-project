package com.example.musicplayerbackend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.HashOperations;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.SetOperations;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PeerTrackingServiceTest {

    @Mock
    RedisTemplate<String, String> redisTemplate;
    @Mock
    ObjectMapper objectMapper;
    @Mock
    HashOperations<String, Object, Object> hashOperations;
    @Mock
    SetOperations<String, String> setOperations;

    PeerTrackingService service;

    @Test
    void shouldStorePeerChunksWhenRegistered() throws Exception {
        service = new PeerTrackingService(redisTemplate, objectMapper);
        when(redisTemplate.opsForHash()).thenReturn(hashOperations);
        when(redisTemplate.opsForSet()).thenReturn(setOperations);
        when(hashOperations.get("peer:chunks:hash-1", "peer-A")).thenReturn(null);
        when(objectMapper.writeValueAsString(any())).thenReturn("[0,1,2]");

        service.registerPeerChunks("hash-1", "peer-A", Set.of(0, 1, 2));

        verify(hashOperations).put("peer:chunks:hash-1", "peer-A", "[0,1,2]");
        verify(setOperations).add("peer:songs:peer-A", "hash-1");
    }

    @Test
    void shouldAccumulateChunksForSamePeer() throws Exception {
        service = new PeerTrackingService(redisTemplate, objectMapper);
        when(redisTemplate.opsForHash()).thenReturn(hashOperations);
        when(redisTemplate.opsForSet()).thenReturn(setOperations);
        when(hashOperations.get("peer:chunks:hash-1", "peer-A")).thenReturn("[0,1]");
        when(objectMapper.readValue(eq("[0,1]"), any(TypeReference.class))).thenReturn(Set.of(0, 1));
        when(objectMapper.writeValueAsString(any())).thenReturn("[0,1,2,3]");

        service.registerPeerChunks("hash-1", "peer-A", Set.of(2, 3));

        verify(hashOperations).put("peer:chunks:hash-1", "peer-A", "[0,1,2,3]");
    }

    @Test
    void shouldSwallowRegisterExceptions() {
        service = new PeerTrackingService(redisTemplate, objectMapper);
        when(redisTemplate.opsForHash()).thenReturn(hashOperations);
        when(hashOperations.get("peer:chunks:hash-1", "peer-A")).thenThrow(new RuntimeException("boom"));

        assertDoesNotThrow(() -> service.registerPeerChunks("hash-1", "peer-A", Set.of(0)));
    }

    @Test
    void shouldRemoveAllChunksForPeerWhenUnregistered() {
        service = new PeerTrackingService(redisTemplate, objectMapper);
        when(redisTemplate.opsForHash()).thenReturn(hashOperations);
        when(redisTemplate.opsForSet()).thenReturn(setOperations);
        when(setOperations.members("peer:songs:peer-A")).thenReturn(Set.of("hash-1", "hash-2"));

        service.unregisterPeer("peer-A");

        verify(hashOperations).delete("peer:chunks:hash-1", "peer-A");
        verify(hashOperations).delete("peer:chunks:hash-2", "peer-A");
        verify(redisTemplate).delete("peer:songs:peer-A");
    }

    @Test
    void shouldHandleNullSongIdsWhenUnregisteringPeer() {
        service = new PeerTrackingService(redisTemplate, objectMapper);
        when(redisTemplate.opsForSet()).thenReturn(setOperations);
        when(setOperations.members("peer:songs:peer-A")).thenReturn(null);

        service.unregisterPeer("peer-A");

        verify(redisTemplate).delete("peer:songs:peer-A");
    }

    @Test
    void shouldSwallowUnregisterExceptions() {
        service = new PeerTrackingService(redisTemplate, objectMapper);
        when(redisTemplate.opsForSet()).thenThrow(new RuntimeException("boom"));

        assertDoesNotThrow(() -> service.unregisterPeer("peer-A"));
    }

    @Test
    void shouldReturnEmptyMapWhenNoPeersExistForSong() {
        service = new PeerTrackingService(redisTemplate, objectMapper);
        when(redisTemplate.opsForHash()).thenReturn(hashOperations);
        when(hashOperations.entries("peer:chunks:hash-1")).thenReturn(Collections.emptyMap());

        Map<String, Set<Integer>> result = service.getPeerBufferMapsForSong("hash-1");

        assertTrue(result.isEmpty());
    }

    @Test
    void shouldReturnImmutablePeerBufferMapForSong() throws Exception {
        service = new PeerTrackingService(redisTemplate, objectMapper);
        when(redisTemplate.opsForHash()).thenReturn(hashOperations);
        Map<Object, Object> raw = new HashMap<>();
        raw.put("peer-A", "[0,1]");
        raw.put("peer-B", "[2]");
        when(hashOperations.entries("peer:chunks:hash-1")).thenReturn(raw);
        when(objectMapper.readValue(eq("[0,1]"), any(TypeReference.class))).thenReturn(Set.of(0, 1));
        when(objectMapper.readValue(eq("[2]"), any(TypeReference.class))).thenReturn(Set.of(2));

        Map<String, Set<Integer>> result = service.getPeerBufferMapsForSong("hash-1");

        assertEquals(2, result.size());
        assertEquals(Set.of(0, 1), result.get("peer-A"));
        assertEquals(Set.of(2), result.get("peer-B"));
        assertThrows(UnsupportedOperationException.class, () -> result.put("peer-C", Set.of(3)));
    }

    @Test
    void shouldReturnEmptyMapWhenBufferMapDecodingFails() throws Exception {
        service = new PeerTrackingService(redisTemplate, objectMapper);
        when(redisTemplate.opsForHash()).thenReturn(hashOperations);
        Map<Object, Object> raw = new HashMap<>();
        raw.put("peer-A", "not-json");
        when(hashOperations.entries("peer:chunks:hash-1")).thenReturn(raw);
        when(objectMapper.readValue(eq("not-json"), any(TypeReference.class))).thenThrow(new RuntimeException("decode error"));

        Map<String, Set<Integer>> result = service.getPeerBufferMapsForSong("hash-1");

        assertTrue(result.isEmpty());
    }
}