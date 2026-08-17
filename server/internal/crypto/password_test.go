package crypto

import "testing"

func TestHashAndVerifyPassword(t *testing.T) {
	hash, err := HashPassword("correct horse battery staple")
	if err != nil {
		t.Fatalf("HashPassword: %v", err)
	}

	ok, err := VerifyPassword("correct horse battery staple", hash)
	if err != nil {
		t.Fatalf("VerifyPassword: %v", err)
	}
	if !ok {
		t.Error("expected correct password to verify")
	}

	ok, err = VerifyPassword("wrong password", hash)
	if err != nil {
		t.Fatalf("VerifyPassword: %v", err)
	}
	if ok {
		t.Error("expected wrong password to fail verification")
	}
}

func TestHashPassword_UniqueSalts(t *testing.T) {
	h1, _ := HashPassword("same password")
	h2, _ := HashPassword("same password")
	if h1 == h2 {
		t.Error("two hashes of the same password with random salts should differ")
	}
}

func TestVerifyPassword_MalformedHash(t *testing.T) {
	if _, err := VerifyPassword("x", "not-a-valid-hash"); err == nil {
		t.Error("expected error for malformed hash")
	}
}

func TestHMACSHA256Hex_Deterministic(t *testing.T) {
	key := []byte("server-secret")
	a := HMACSHA256Hex(key, []byte("alice@example.com"))
	b := HMACSHA256Hex(key, []byte("alice@example.com"))
	if a != b {
		t.Error("HMACSHA256Hex should be deterministic for the same input")
	}

	c := HMACSHA256Hex(key, []byte("bob@example.com"))
	if a == c {
		t.Error("HMACSHA256Hex should differ for different messages")
	}
}
