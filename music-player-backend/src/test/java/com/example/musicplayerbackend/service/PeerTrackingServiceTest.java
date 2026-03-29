package com.example.musicplayerbackend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.StringRedisSerializer;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

@Testcontainers
class PeerTrackingServiceTest {

    @Container
    @SuppressWarnings("resource")
    static final GenericContainer<?> redis =
            new GenericContainer<>("redis:7-alpine").withExposedPorts(6379);

    PeerTrackingService service;
    RedisTemplate<String, String> redisTemplate;

    @BeforeEach
    void setUp() {
        LettuceConnectionFactory factory = new LettuceConnectionFactory(redis.getHost(), redis.getMappedPort(6379));
        factory.afterPropertiesSet();

        StringRedisSerializer str = new StringRedisSerializer();
        redisTemplate = new RedisTemplate<>();
        redisTemplate.setConnectionFactory(factory);
        redisTemplate.setKeySerializer(str);
        redisTemplate.setValueSerializer(str);
        redisTemplate.setHashKeySerializer(str);
        redisTemplate.setHashValueSerializer(str);
        redisTemplate.afterPropertiesSet();

        // Flush between tests for isolation
        redisTemplate.getConnectionFactory().getConnection().serverCommands().flushAll();

        service = new PeerTrackingService(redisTemplate, new ObjectMapper());
    }

    @Test
    void shouldStorePeerChunksWhenRegistered() {
        service.registerPeerChunks(1, "peer-A", Set.of(0, 1, 2));

        Map<String, Set<Integer>> result = service.getPeerBufferMapsForSong(1);

        assertEquals(1, result.size());
        assertTrue(result.containsKey("peer-A"));
        assertEquals(Set.of(0, 1, 2), result.get("peer-A"));
    }

    @Test
    void shouldAccumulateChunksForSamePeer() {
        service.registerPeerChunks(1, "peer-A", Set.of(0, 1));
        service.registerPeerChunks(1, "peer-A", Set.of(2, 3));

        Set<Integer> chunks = service.getPeerBufferMapsForSong(1).get("peer-A");

        assertEquals(Set.of(0, 1, 2, 3), chunks);
    }

    @Test
    void shouldHandleMultiplePeersForSameSong() {
        service.registerPeerChunks(1, "peer-A", Set.of(0));
        service.registerPeerChunks(1, "peer-B", Set.of(1));

        Map<String, Set<Integer>> result = service.getPeerBufferMapsForSong(1);

        assertEquals(2, result.size());
        assertTrue(result.containsKey("peer-A"));
        assertTrue(result.containsKey("peer-B"));
    }

    @Test
    void shouldIsolateSongRegistriesWhenRegisteringPeerChunks() {
        service.registerPeerChunks(1, "peer-A", Set.of(0, 1));
        service.registerPeerChunks(2, "peer-A", Set.of(5, 6));

        assertEquals(Set.of(0, 1), service.getPeerBufferMapsForSong(1).get("peer-A"));
        assertEquals(Set.of(5, 6), service.getPeerBufferMapsForSong(2).get("peer-A"));
    }

    @Test
    void shouldReturnEmptyPeerBufferMapsWhenNoRegistrations() {
        Map<String, Set<Integer>> result = service.getPeerBufferMapsForSong(999);
        assertTrue(result.isEmpty());
    }

    @Test
    void shouldReturnImmutableCopyOfPeerBufferMaps() {
        service.registerPeerChunks(1, "peer-A", Set.of(0));
        Map<String, Set<Integer>> result = service.getPeerBufferMapsForSong(1);
        assertThrows(UnsupportedOperationException.class, () -> result.put("new-peer", Set.of()));
    }

    @Test
    void shouldRemoveAllChunksForPeerWhenUnregistered() {
        service.registerPeerChunks(1, "peer-A", Set.of(0, 1));
        service.registerPeerChunks(2, "peer-A", Set.of(5));

        service.unregisterPeer("peer-A");

        assertTrue(service.getPeerBufferMapsForSong(1).isEmpty());
        assertTrue(service.getPeerBufferMapsForSong(2).isEmpty());
    }

    @Test
    void shouldRemoveEmptySongEntriesWhenPeerUnregistered() {
        service.registerPeerChunks(1, "peer-A", Set.of(0));
        service.unregisterPeer("peer-A");

        assertTrue(service.getPeerBufferMapsForSong(1).isEmpty());
    }

    @Test
    void shouldOnlyRemoveTargetPeerLeavingOthers() {
        service.registerPeerChunks(1, "peer-A", Set.of(0));
        service.registerPeerChunks(1, "peer-B", Set.of(1));

        service.unregisterPeer("peer-A");

        Map<String, Set<Integer>> result = service.getPeerBufferMapsForSong(1);
        assertFalse(result.containsKey("peer-A"));
        assertTrue(result.containsKey("peer-B"));
    }

    @Test
    void shouldBeNoOpWhenUnregisteringUnknownPeer() {
        assertDoesNotThrow(() -> service.unregisterPeer("unknown-peer"));
    }
}