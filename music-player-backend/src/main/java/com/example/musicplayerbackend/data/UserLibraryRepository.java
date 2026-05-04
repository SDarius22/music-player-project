package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.UserLibrary;
import com.example.musicplayerbackend.domain.UserLibraryID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Collection;
import java.util.List;

@Repository
public interface UserLibraryRepository extends JpaRepository<UserLibrary, UserLibraryID> {

    List<UserLibrary> findByIdUserIdAndLastUpdatedAfter(Long userId, Instant lastUpdated);

    List<UserLibrary> findByIdUserIdAndIsDeletedFalse(Long userId);

    List<UserLibrary> findByIdUserIdAndIdSongIdIn(Long userId, Collection<Long> songIds);

    @Query("SELECT ul FROM UserLibrary ul WHERE ul.id.userId = :userId AND ul.liked = true AND ul.isDeleted = false ORDER BY ul.playCount DESC")
    Page<UserLibrary> findLikedByUserId(@Param("userId") Long userId, Pageable pageable);

    @Query("SELECT ul FROM UserLibrary ul WHERE ul.id.userId = :userId AND ul.isDeleted = false AND ul.playCount > 0 ORDER BY ul.playCount DESC")
    Page<UserLibrary> findMostPlayedByUserId(@Param("userId") Long userId, Pageable pageable);

    @Query("SELECT ul FROM UserLibrary ul WHERE ul.id.userId = :userId AND ul.isDeleted = false AND ul.playCount > 0 AND (ul.lastPlayed IS NULL OR ul.lastPlayed < :cutoff) ORDER BY ul.playCount DESC")
    Page<UserLibrary> findRecommendationsByUserId(@Param("userId") Long userId, @Param("cutoff") Instant cutoff, Pageable pageable);

    @Query("SELECT ul FROM UserLibrary ul WHERE ul.id.userId = :userId AND ul.isDeleted = false AND ul.playCount > 0 AND ul.lastPlayed IS NOT NULL AND ul.lastPlayed < :cutoff ORDER BY ul.lastPlayed ASC")
    Page<UserLibrary> findForgottenByUserId(@Param("userId") Long userId, @Param("cutoff") Instant cutoff, Pageable pageable);

    @Query("SELECT ul FROM UserLibrary ul WHERE ul.id.userId = :userId AND ul.isDeleted = false ORDER BY ul.addedAt DESC")
    Page<UserLibrary> findRecentlyAddedByUserId(@Param("userId") Long userId, Pageable pageable);

    @Query("SELECT ul FROM UserLibrary ul WHERE ul.id.userId = :userId AND ul.isDeleted = false AND ul.lastPlayed IS NOT NULL ORDER BY ul.lastPlayed DESC")
    Page<UserLibrary> findRecentlyPlayedByUserId(@Param("userId") Long userId, Pageable pageable);

    @Query("SELECT ul FROM UserLibrary ul WHERE ul.id.userId = :userId AND ul.isDeleted = false ORDER BY COALESCE(ul.lastPlayed, ul.addedAt) DESC")
    Page<UserLibrary> findQuickDialByUserId(@Param("userId") Long userId, Pageable pageable);
}
