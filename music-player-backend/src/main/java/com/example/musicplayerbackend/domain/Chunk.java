package com.example.musicplayerbackend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "chunks")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Chunk {
  public static final int MAX_SIZE_BYTES = 64 * 1024;

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false, unique = true, length = 64)
  private String contentHash;

  @Column(nullable = false)
  private Integer size;

  @Column(nullable = false)
  private String storagePath;
}
