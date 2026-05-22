package com.example.musicplayerbackend.helpers;

import java.util.Base64;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

public class CoverDecoder {

  public static byte[] decodeCoverImage(String coverImage) {
    if (coverImage == null || coverImage.isBlank()) {
      throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Cover not found");
    }
    String base64 = coverImage;
    if (coverImage.startsWith("data:")) {
      int commaIdx = coverImage.indexOf(',');
      if (commaIdx >= 0) {
        base64 = coverImage.substring(commaIdx + 1);
      }
    }
    try {
      return Base64.getDecoder().decode(base64.trim());
    } catch (IllegalArgumentException e) {
      throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Cover not found");
    }
  }
}
