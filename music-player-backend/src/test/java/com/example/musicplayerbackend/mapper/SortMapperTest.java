package com.example.musicplayerbackend.mapper;

import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Sort;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SortMapperTest {

    private final SortMapper mapper = new SortMapper() {
    };

    @Test
    void shouldReturnDefaultSortWhenInputIsNull() {
        Sort sort = mapper.toSort(null);

        assertEquals("name: ASC", sort.toString());
    }

    @Test
    void shouldReturnDefaultSortWhenInputIsBlank() {
        Sort sort = mapper.toSort("   ");

        assertEquals("name: ASC", sort.toString());
    }

    @Test
    void shouldReturnDescendingSortWhenRequested() {
        Sort sort = mapper.toSort("name,desc");

        assertEquals("name: DESC", sort.toString());
    }

    @Test
    void shouldReturnAscendingSortWhenDirectionMissing() {
        Sort sort = mapper.toSort("name");

        assertEquals("name: ASC", sort.toString());
    }

    @Test
    void shouldTreatUppercaseDescAsAscendingByCurrentContract() {
        Sort sort = mapper.toSort("name,DESC");

        assertEquals("name: ASC", sort.toString());
    }
}

