package com.example.musicplayerbackend.data;

import com.example.musicplayerbackend.domain.VerificationCode;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface VerificationCodeRepository extends JpaRepository<VerificationCode, Long> {
  Optional<VerificationCode> findByEmail(String email);
}
