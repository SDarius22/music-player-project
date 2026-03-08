package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.UserLibrary;
import com.example.musicplayerbackend.domain.UserLibraryID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

@Repository
public interface UserLibraryRepository extends JpaRepository<UserLibrary, UserLibraryID> {

    List<UserLibrary> findByUserIdAndLastUpdatedAfter(Long userId, Instant lastUpdated);

    List<UserLibrary> findByUserIdAndIsDeletedFalse(Long userId);
}
