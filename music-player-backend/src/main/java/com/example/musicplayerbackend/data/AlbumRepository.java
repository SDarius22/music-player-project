package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Album;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AlbumRepository extends JpaRepository<Album, Long> {
  Optional<Album> findByHash(String hash);

  Page<Album> findAllByNameContainingIgnoreCase(String query, Pageable pageable);
}
