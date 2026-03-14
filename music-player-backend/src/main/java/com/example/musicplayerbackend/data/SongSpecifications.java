package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongType;
import jakarta.persistence.criteria.JoinType;
import org.springframework.data.jpa.domain.Specification;

/**
 * Reusable JPA Specifications for filtering songs.
 */
public final class SongSpecifications {

    private SongSpecifications() {
    }

    /**
     * Visibility rule:
     * - anonymous: only streamable songs
     * - authenticated: streamable OR user-uploaded songs owned by the current user
     */
    public static Specification<Song> visibleTo(Long userId) {
        return (root, query, cb) -> {
            // We often sort/filter on artist/album fields; keep joins predictable.
            root.fetch("artist", JoinType.LEFT);
            root.fetch("album", JoinType.LEFT);
            query.distinct(true);

            var streamable = cb.equal(root.get("songType"), SongType.STREAMABLE);
            if (userId == null) {
                return streamable;
            }

            var ownedUpload = cb.and(
                    cb.equal(root.get("songType"), SongType.USER_UPLOAD),
                    cb.equal(root.get("ownerId"), userId)
            );
            return cb.or(streamable, ownedUpload);
        };
    }

    /**
     * Case-insensitive substring search across song name, artist name, and album name.
     */
    public static Specification<Song> matchesQuery(String q) {
        if (q == null || q.isBlank()) {
            return Specification.where(null);
        }
        final String like = "%" + q.trim().toLowerCase() + "%";

        return (root, query, cb) -> {
            var artistJoin = root.join("artist", JoinType.LEFT);
            var albumJoin = root.join("album", JoinType.LEFT);

            var songName = cb.like(cb.lower(root.get("name")), like);
            var artistName = cb.like(cb.lower(artistJoin.get("name")), like);
            var albumName = cb.like(cb.lower(albumJoin.get("name")), like);

            return cb.or(songName, artistName, albumName);
        };
    }
}

