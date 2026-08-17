package crypto

import (
	"crypto/hmac"
	"crypto/sha256"
)

func hmacSHA256(key, message []byte) []byte {
	mac := hmac.New(sha256.New, key)
	mac.Write(message)
	return mac.Sum(nil)
}
