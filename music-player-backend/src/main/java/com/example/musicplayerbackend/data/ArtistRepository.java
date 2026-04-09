package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Artist;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ArtistRepository extends JpaRepository<Artist, Long> {
    Optional<Artist> findByHash(String hash);

    Page<Artist> findAllByNameContainingIgnoreCase(String query, Pageable pageable);
}
