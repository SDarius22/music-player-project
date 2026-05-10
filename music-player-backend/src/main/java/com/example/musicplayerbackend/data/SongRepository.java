package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.data.specification.SongSpecification;
import com.example.musicplayerbackend.domain.Song;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Repository;

@Repository
public interface SongRepository extends JpaRepository<Song, Long>, JpaSpecificationExecutor<Song> {

  @Override
  @EntityGraph(attributePaths = {"artist", "album"})
  Optional<Song> findById(Long id);

  @EntityGraph(attributePaths = {"artist", "album"})
  Optional<Song> findByFileHash(String fileHash);

  List<Song> findAllByFileHashIn(List<String> fileHashes);

  @Query(value = "SELECT * FROM music_library.songs WHERE song_type = 'STREAMABLE' ORDER BY RANDOM()", nativeQuery = true)
  List<Song> findRandomStreamable(Pageable pageable);

  default Page<Song> findVisibleToUser(String q, Long userId, Pageable pageable) {
    Specification<Song> spec = SongSpecification.visibleToUser(userId);
    Specification<Song> querySpec = SongSpecification.matchesQuery(q);
    if (querySpec != null) {
      spec = spec.and(querySpec);
    }
    return findAll(spec, pageable);
  }
}