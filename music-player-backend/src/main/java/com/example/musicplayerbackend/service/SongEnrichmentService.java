package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.UserLibraryRepository;
import com.example.musicplayerbackend.domain.Song;
import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.domain.UserLibrary;
import com.example.musicplayerbackend.domain.UserLibraryID;
import com.example.musicplayerbackend.mapper.SongMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SongEnrichmentService {

    private final UserLibraryRepository userLibraryRepository;
    private final SongMapper songMapper;

    @Transactional(readOnly = true)
    public SongDto enrich(Song song, Long userId) {
        if (song == null) {
            return null;
        }
        if (userId == null || song.getId() == null) {
            return songMapper.toDto(song, null);
        }
        UserLibrary entry = userLibraryRepository
                .findById(new UserLibraryID(userId, song.getId()))
                .filter(ul -> !Boolean.TRUE.equals(ul.getIsDeleted()))
                .orElse(null);
        return songMapper.toDto(song, entry);
    }

    @Transactional(readOnly = true)
    public List<SongDto> enrich(List<Song> songs, Long userId) {
        if (songs == null || songs.isEmpty()) {
            return List.of();
        }
        if (userId == null) {
            return songs.stream().map(s -> songMapper.toDto(s, null)).toList();
        }
        List<Long> songIds = songs.stream()
                .map(Song::getId)
                .filter(java.util.Objects::nonNull)
                .toList();
        Map<Long, UserLibrary> byId = userLibraryRepository
                .findByIdUserIdAndIdSongIdIn(userId, songIds).stream()
                .filter(ul -> !Boolean.TRUE.equals(ul.getIsDeleted()))
                .collect(Collectors.toMap(ul -> ul.getId().getSongId(), Function.identity()));
        return songs.stream()
                .map(s -> songMapper.toDto(s, byId.get(s.getId())))
                .toList();
    }
}
