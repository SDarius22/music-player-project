package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.UserLibrary;
import com.example.musicplayerbackend.domain.UserLibraryID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface UserLibraryRepository extends JpaRepository<UserLibrary, UserLibraryID> {
}
