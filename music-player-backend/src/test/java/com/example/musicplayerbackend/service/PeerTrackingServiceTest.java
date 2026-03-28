package com.example.musicplayerbackend.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class PeerTrackingServiceTest {

    PeerTrackingService service;

    @BeforeEach
    void setUp() {
        service = new PeerTrackingService();
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

        // After removing the only peer, the song entry should also be cleaned up
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
