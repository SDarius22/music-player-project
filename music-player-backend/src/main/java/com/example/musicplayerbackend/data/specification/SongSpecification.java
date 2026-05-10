package com.example.musicplayerbackend.data.specification;

import com.example.musicplayerbackend.domain.PlaylistSong;
import com.example.musicplayerbackend.domain.Song;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Subquery;
import org.springframework.data.jpa.domain.Specification;

public final class SongSpecification {

  private SongSpecification() {
  }

  public static Specification<Song> visibleToUser(Long userId) {
    return (root, query, cb) ->
        cb.or(
            cb.equal(root.get("ownerId"), userId),
            cb.isNull(root.get("ownerId"))
        );
  }

  public static Specification<Song> matchesQuery(String q) {
    if (q == null || q.isBlank()) {
      return null;
    }

    return (root, query, cb) -> {
      String like = "%" + q.toLowerCase() + "%";

      Join<Object, Object> artist = root.join("artist", JoinType.LEFT);
      Join<Object, Object> album = root.join("album", JoinType.LEFT);

      return cb.or(
          cb.like(cb.lower(root.get("name")), like),
          cb.like(cb.lower(artist.get("name")), like),
          cb.like(cb.lower(album.get("name")), like)
      );
    };
  }

  public static Specification<Song> hasAlbumHash(String albumHash) {
    if (albumHash == null || albumHash.isBlank()) {
      return null;
    }

    return (root, query, cb) -> {
      Join<Object, Object> album = root.join("album", JoinType.INNER);
      return cb.equal(album.get("hash"), albumHash);
    };
  }

  public static Specification<Song> hasArtistHash(String artistHash) {
    if (artistHash == null || artistHash.isBlank()) {
      return null;
    }

    return (root, query, cb) -> {
      Join<Object, Object> artist = root.join("artist", JoinType.INNER);
      return cb.equal(artist.get("hash"), artistHash);
    };
  }

  public static Specification<Song> inPlaylist(Long playlistId) {
    if (playlistId == null) {
      return null;
    }

    return (root, query, cb) -> {
      Subquery<Long> sq = query.subquery(Long.class);
      var ps = sq.from(PlaylistSong.class);

      sq.select(cb.literal(1L));
      sq.where(
          cb.equal(ps.get("playlist").get("id"), playlistId),
          cb.equal(ps.get("song").get("fileHash"), root.get("fileHash"))
      );

      return cb.exists(sq);
    };
  }
}
