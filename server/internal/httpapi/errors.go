// Package httpapi assembles the HTTP server: routing, cross-cutting
// middleware (panic recovery, request logging, body size limits, HTTPS
// enforcement), and the JSON request/response envelope shared by every
// endpoint group.
package httpapi

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// APIError is a JSON-serializable error with an HTTP status code attached.
type APIError struct {
	Status  int    `json:"-"`
	Code    string `json:"error"`
	Message string `json:"message,omitempty"`
}

func (e *APIError) Error() string { return e.Code }

// Common errors reused across handler packages.
func NewError(status int, code, message string) *APIError {
	return &APIError{Status: status, Code: code, Message: message}
}

func ErrBadRequest(message string) *APIError {
	return NewError(http.StatusBadRequest, "bad_request", message)
}
func ErrUnauthorized(message string) *APIError {
	return NewError(http.StatusUnauthorized, "unauthorized", message)
}
func ErrForbidden(message string) *APIError {
	return NewError(http.StatusForbidden, "forbidden", message)
}
func ErrNotFound(message string) *APIError {
	return NewError(http.StatusNotFound, "not_found", message)
}
func ErrConflict(message string) *APIError { return NewError(http.StatusConflict, "conflict", message) }
func ErrGone(message string) *APIError     { return NewError(http.StatusGone, "gone", message) }
func ErrTooLarge(message string) *APIError {
	return NewError(http.StatusRequestEntityTooLarge, "payload_too_large", message)
}
func ErrInternal(message string) *APIError {
	return NewError(http.StatusInternalServerError, "internal_error", message)
}

// WriteJSON writes v as a JSON response with the given status code.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if v == nil {
		return
	}
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("httpapi: encode response failed", "error", err)
	}
}

// WriteError writes err as a JSON error envelope. Non-*APIError values are
// treated as unexpected internal errors and logged at error level; the
// client only ever sees a generic message for those, never the underlying
// error text (which could leak internal detail).
func WriteError(w http.ResponseWriter, err error) {
	if apiErr, ok := err.(*APIError); ok {
		WriteJSON(w, apiErr.Status, apiErr)
		return
	}
	slog.Error("httpapi: unhandled error", "error", err)
	WriteJSON(w, http.StatusInternalServerError, &APIError{Code: "internal_error", Message: "internal server error"})
}

// DecodeJSON decodes the request body into v, returning a *APIError on
// failure.
func DecodeJSON(r *http.Request, v any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		return ErrBadRequest("invalid request body: " + err.Error())
	}
	return nil
}
