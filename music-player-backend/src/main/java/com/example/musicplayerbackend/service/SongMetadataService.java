package com.example.musicplayerbackend.service;

import com.example.musicplayerbackend.data.SongRepository;
import com.example.musicplayerbackend.domain.SongDto;
import com.example.musicplayerbackend.mapper.SongMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SongMetadataService {

    private final SongRepository songRepository;
    private final SongMapper songMapper;

    @Transactional(readOnly = true)
    public List<SongDto> getAllSongs() {
        return songRepository.findAll()
                .stream()
                .map(songMapper::toDto)
                .toList();
    }
}