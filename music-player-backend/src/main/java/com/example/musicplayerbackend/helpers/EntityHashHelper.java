package com.example.musicplayerbackend.helpers;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class EntityHashHelper {

    private EntityHashHelper() {
    }

    public static String artistHash(String artistName) {
        return sha256Hex(normalize(artistName));
    }

    public static String albumHash(String artistName, String albumName) {
        return sha256Hex(normalize(artistName) + " - " + normalize(albumName));
    }

    private static String sha256Hex(String value) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8))
            );
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is not available", e);
        }
    }

    private static String normalize(String value) {
        return value == null ? "" : value;
    }
}
