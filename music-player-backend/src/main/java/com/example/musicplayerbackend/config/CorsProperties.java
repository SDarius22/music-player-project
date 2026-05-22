package com.example.musicplayerbackend.config;

import java.util.Arrays;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class CorsProperties {

  private final List<String> allowedOrigins;

  public CorsProperties(
      @Value("${application.security.cors.allowed-origins}") String allowedOrigins) {
    this.allowedOrigins =
        Arrays.stream(allowedOrigins.split(","))
            .map(String::trim)
            .filter(origin -> !origin.isBlank())
            .toList();
  }

  public List<String> allowedOrigins() {
    return allowedOrigins;
  }
}
