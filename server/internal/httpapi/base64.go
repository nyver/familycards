package httpapi

import "encoding/base64"

// DecodeBinaryField decodes a standard-alphabet, padded base64 string as
// used for every binary field in the wire protocol (nonces, ciphertext,
// keys, salts). Returns a *APIError naming the field on failure.
func DecodeBinaryField(fieldName, value string) ([]byte, error) {
	b, err := base64.StdEncoding.DecodeString(value)
	if err != nil {
		return nil, ErrBadRequest("invalid base64 for field: " + fieldName)
	}
	return b, nil
}

// EncodeBinaryField encodes bytes using the standard, padded base64
// alphabet required by the wire protocol.
func EncodeBinaryField(b []byte) string {
	return base64.StdEncoding.EncodeToString(b)
}
