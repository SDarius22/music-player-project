package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Album;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface AlbumRepository extends JpaRepository<Album, Long> {
    Optional<Album> findByName(String albumName);

    @Query("SELECT a FROM Album a LEFT JOIN a.artist ar " +
           "WHERE :q IS NULL OR LOWER(a.name) LIKE LOWER(CONCAT('%', :q, '%')) " +
           "OR LOWER(ar.name) LIKE LOWER(CONCAT('%', :q, '%'))")
    Page<Album> findAllByQuery(@Param("q") String q, Pageable pageable);
}
