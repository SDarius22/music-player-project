package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.*;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

import java.util.UUID;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class SongRepositoryTest extends BaseRepositoryTest {

    @Autowired
    SongRepository songRepository;

    @Autowired
    ArtistRepository artistRepository;

    @Autowired
    AlbumRepository albumRepository;

    @Autowired
    UserRepository userRepository;

    @Autowired
    EntityManager em;

    private Artist artist;
    private Album album;
    private User user;

    @BeforeEach
    void setUp() {
        artist = artistRepository.save(Artist.builder().name("Queen").build());
        album  = albumRepository.save(Album.builder().name("A Kind of Magic").artists(Set.of(artist)).build());
        user   = userRepository.save(buildUser("songs@example.com"));
    }

    @AfterEach
    void tearDown() {
        songRepository.deleteAll();
        albumRepository.deleteAll();
        artistRepository.deleteAll();
        userRepository.deleteAll();
    }

    private Song streamable(String name) {
        return Song.builder()
                .name(name).artist(artist).album(album)
                .songType(ContentType.STREAMABLE)
                .fileHash(UUID.randomUUID().toString())
                .build();
    }

    private Song userUpload(String name, Long ownerId) {
        return Song.builder()
                .name(name).artist(artist).album(album)
                .songType(ContentType.USER_UPLOAD)
                .ownerId(ownerId)
                .fileHash(UUID.randomUUID().toString())
                .build();
    }

    // ── findById (EntityGraph) ───────────────────────────────────────────────

    @Test
    void shouldLoadArtistAndAlbumViaEntityGraph() {
        Song saved = songRepository.save(streamable("Bohemian Rhapsody"));
        em.clear(); // save() already commits; clear evicts the entity so findById hits the DB

        var found = songRepository.findById(saved.getId());

        assertThat(found).isPresent();
        // Accessing these should not throw LazyInitializationException
        assertThat(found.get().getArtist().getName()).isEqualTo("Queen");
        assertThat(found.get().getAlbum().getName()).isEqualTo("A Kind of Magic");
    }

    @Test
    void shouldReturnEmptyWhenSongIdNotFound() {
        assertThat(songRepository.findById(Long.MAX_VALUE)).isEmpty();
    }

    // ── findByFileHash ───────────────────────────────────────────────────────

    @Test
    void shouldReturnOptionalWhenFileHashExists() {
        String hash = "unique-file-hash-abc";
        songRepository.save(Song.builder()
                .name("Track").artist(artist).album(album)
                .songType(ContentType.STREAMABLE).fileHash(hash).build());

        var found = songRepository.findByFileHash(hash);

        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("Track");
    }

    @Test
    void shouldReturnEmptyWhenFileHashNotFound() {
        assertThat(songRepository.findByFileHash("nonexistent-hash")).isEmpty();
    }

    // ── findRandomStreamable ─────────────────────────────────────────────────

    @Test
    void shouldReturnOnlyStreamableSongs() {
        songRepository.save(streamable("Streamable 1"));
        songRepository.save(streamable("Streamable 2"));
        songRepository.save(userUpload("User Upload", user.getId()));

        var results = songRepository.findRandomStreamable(PageRequest.of(0, 10));

        assertThat(results).isNotEmpty();
        assertThat(results).allSatisfy(s -> assertThat(s.getSongType()).isEqualTo(ContentType.STREAMABLE));
    }

    @Test
    void shouldReturnEmptyWhenNoStreamableSongs() {
        songRepository.save(userUpload("Upload Only", user.getId()));

        var results = songRepository.findRandomStreamable(PageRequest.of(0, 10));

        assertThat(results).isEmpty();
    }

    @Test
    void shouldRespectPageSizeForRandomStreamable() {
        for (int i = 0; i < 5; i++) {
            songRepository.save(streamable("Streamable " + i));
        }

        var results = songRepository.findRandomStreamable(PageRequest.of(0, 3));

        assertThat(results).hasSize(3);
    }

    // ── findVisibleToUser ────────────────────────────────────────────────────

    @Test
    void shouldReturnPublicSongsOwnedByNobody() {
        songRepository.save(streamable("Public Song"));

        Page<Song> result = songRepository.findVisibleToUser("Public", user.getId(), PageRequest.of(0, 10));

        assertThat(result.getContent()).hasSize(1);
        assertThat(result.getContent().getFirst().getName()).isEqualTo("Public Song");
    }

    @Test
    void shouldReturnOwnSongs() {
        songRepository.save(userUpload("My Upload", user.getId()));

        Page<Song> result = songRepository.findVisibleToUser("My Upload", user.getId(), PageRequest.of(0, 10));

        assertThat(result.getContent()).hasSize(1);
    }

    @Test
    void shouldNotReturnOtherUsersSongs() {
        User otherUser = userRepository.save(buildUser("other@example.com"));
        songRepository.save(userUpload("Other's Song", otherUser.getId()));

        Page<Song> result = songRepository.findVisibleToUser("Other's Song", user.getId(), PageRequest.of(0, 10));

        assertThat(result.getContent()).isEmpty();
    }

    @Test
    void shouldSearchByArtistName() {
        songRepository.save(streamable("Any Title"));

        // Artist is "Queen" — search by artist name
        Page<Song> result = songRepository.findVisibleToUser("Queen", user.getId(), PageRequest.of(0, 10));

        assertThat(result.getContent()).isNotEmpty();
    }

    @Test
    void shouldSearchByAlbumName() {
        songRepository.save(streamable("Any Title 2"));

        // Album is "A Kind of Magic"
        Page<Song> result = songRepository.findVisibleToUser("Kind of Magic", user.getId(), PageRequest.of(0, 10));

        assertThat(result.getContent()).isNotEmpty();
    }

    @Test
    void shouldBeCaseInsensitiveWhenSearchingSongs() {
        songRepository.save(streamable("We Will Rock You"));

        Page<Song> lower = songRepository.findVisibleToUser("we will", user.getId(), PageRequest.of(0, 10));
        Page<Song> upper = songRepository.findVisibleToUser("WE WILL", user.getId(), PageRequest.of(0, 10));

        assertThat(lower.getTotalElements()).isEqualTo(1);
        assertThat(upper.getTotalElements()).isEqualTo(1);
    }

    @Test
    void shouldReturnBothPublicAndOwnedSongsForUser() {
        songRepository.save(streamable("Public Track"));
        songRepository.save(userUpload("My Upload", user.getId()));

        // Empty query → all visible songs
        Page<Song> result = songRepository.findVisibleToUser("", user.getId(), PageRequest.of(0, 10));

        assertThat(result.getTotalElements()).isGreaterThanOrEqualTo(2);
        assertThat(result.getContent())
                .anyMatch(s -> s.getSongType() == ContentType.STREAMABLE)
                .anyMatch(s -> s.getSongType() == ContentType.USER_UPLOAD);
    }

    @Test
    void shouldReturnCorrectPageWhenPaginating() {
        for (int i = 0; i < 5; i++) {
            songRepository.save(streamable("Paginated Song " + i));
        }

        Page<Song> page0 = songRepository.findVisibleToUser("Paginated", user.getId(), PageRequest.of(0, 2));
        Page<Song> page1 = songRepository.findVisibleToUser("Paginated", user.getId(), PageRequest.of(1, 2));

        assertThat(page0.getContent()).hasSize(2);
        assertThat(page1.getContent()).hasSize(2);
        assertThat(page0.getTotalElements()).isEqualTo(5);
    }

    @Test
    void shouldReturnEmptyWhenNoVisibleSongsMatch() {
        songRepository.save(streamable("Don't Stop Me Now"));

        Page<Song> result = songRepository.findVisibleToUser("zzznomatch", user.getId(), PageRequest.of(0, 10));

        assertThat(result).isEmpty();
    }
}
