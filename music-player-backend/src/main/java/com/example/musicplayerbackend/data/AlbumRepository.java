package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Album;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface AlbumRepository extends JpaRepository<Album, Long> {
    Optional<Album> findByName(String albumName);

    Page<Album> findAllByNameContainingIgnoreCase(String name, Pageable pageable);
}
