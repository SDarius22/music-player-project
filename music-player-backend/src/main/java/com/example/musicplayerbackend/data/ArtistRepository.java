package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.Artist;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ArtistRepository extends JpaRepository<Artist, Long> {
    Optional<Artist> findByName(String artistName);

    @Query("SELECT a FROM Artist a " +
           "WHERE :q IS NULL OR LOWER(a.name) LIKE LOWER(CONCAT('%', :q, '%'))")
    Page<Artist> findAllByQuery(@Param("q") String q, Pageable pageable);
}
