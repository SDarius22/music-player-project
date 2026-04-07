package com.example.musicplayerbackend.exception;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.core.MethodParameter;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.lang.reflect.Method;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void shouldHandleResponseStatusException() {
        HttpServletRequest request = Mockito.mock(HttpServletRequest.class);
        when(request.getRequestURI()).thenReturn("/api/v1/test");

        ResponseStatusException ex = new ResponseStatusException(HttpStatus.BAD_REQUEST, "bad input");
        ResponseEntity<ErrorResponse> response = handler.handleResponseStatusException(ex, request);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals(400, response.getBody().status());
        assertEquals("Bad Request", response.getBody().error());
        assertEquals("bad input", response.getBody().message());
        assertEquals("/api/v1/test", response.getBody().path());
        assertNotNull(response.getBody().timestamp());
    }

    @Test
    void shouldHandleValidationExceptionByJoiningMessages() throws Exception {
        HttpServletRequest request = Mockito.mock(HttpServletRequest.class);
        when(request.getRequestURI()).thenReturn("/api/v1/validate");

        Method method = ValidationTarget.class.getDeclaredMethod("submit", Payload.class);
        MethodParameter parameter = new MethodParameter(method, 0);

        BeanPropertyBindingResult bindingResult = new BeanPropertyBindingResult(new Payload(), "payload");
        bindingResult.addError(new FieldError("payload", "name", "name is required"));
        bindingResult.addError(new FieldError("payload", "email", "email is required"));

        MethodArgumentNotValidException ex = new MethodArgumentNotValidException(parameter, bindingResult);
        ResponseEntity<ErrorResponse> response = handler.handleValidationException(ex, request);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("name is required, email is required", response.getBody().message());
        assertEquals("/api/v1/validate", response.getBody().path());
    }

    @Test
    void shouldHandleNoResourceFoundException() {
        HttpServletRequest request = Mockito.mock(HttpServletRequest.class);
        when(request.getRequestURI()).thenReturn("/api/v1/missing");

        NoResourceFoundException ex = new NoResourceFoundException(HttpMethod.GET, "/api/v1/missing", "No static resource");
        ResponseEntity<ErrorResponse> response = handler.handleNoResourceFoundException(ex, request);

        assertEquals(HttpStatus.NOT_FOUND, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals("The requested endpoint does not exist.", response.getBody().message());
    }

    @Test
    void shouldHandleUnexpectedExceptionAsInternalServerError() {
        HttpServletRequest request = Mockito.mock(HttpServletRequest.class);
        when(request.getRequestURI()).thenReturn("/api/v1/crash");

        ResponseEntity<ErrorResponse> response = handler.handleAllOtherExceptions(new RuntimeException("boom"), request);

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals(500, response.getBody().status());
        assertEquals("An unexpected internal server error occurred.", response.getBody().message());
        assertEquals("/api/v1/crash", response.getBody().path());
    }

    private static class ValidationTarget {
        void submit(@Valid Payload payload) {
        }
    }

    private static class Payload {
        @NotBlank
        private String name;
    }
}

