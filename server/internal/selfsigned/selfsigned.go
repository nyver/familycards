// Package selfsigned issues and persists a self-signed TLS certificate for
// the server's own TLS termination, with no external services or utilities
// involved (the runtime image has neither a shell nor openssl).
package selfsigned

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	certFileName = "selfsigned.crt"
	keyFileName  = "selfsigned.key"

	// validity is how long an issued certificate is valid for. Ten years
	// means the operator effectively never has to deal with unplanned
	// re-issuance (and the pinned fingerprint changing) as long as the
	// cache directory survives.
	validity = 10 * 365 * 24 * time.Hour

	// clockSkew backdates NotBefore slightly to tolerate small clock
	// differences between the server and a client verifying the cert
	// immediately after issuance.
	clockSkew = 5 * time.Minute
)

// LoadOrIssue returns a TLS certificate covering names, reusing a
// previously issued pair from cacheDir when it exists, is readable, is not
// expired, and covers every one of names. Otherwise it issues a new
// ECDSA P-256 pair and persists it (replacing any existing pair) to
// cacheDir, since re-issuing changes the fingerprint either way.
func LoadOrIssue(cacheDir string, names []string) (tls.Certificate, error) {
	if len(names) == 0 {
		return tls.Certificate{}, fmt.Errorf("selfsigned: at least one name is required")
	}
	if err := os.MkdirAll(cacheDir, 0o700); err != nil {
		return tls.Certificate{}, fmt.Errorf("selfsigned: create cache dir: %w", err)
	}

	certPath := filepath.Join(cacheDir, certFileName)
	keyPath := filepath.Join(cacheDir, keyFileName)

	if cert, ok := tryLoad(certPath, keyPath, names); ok {
		return cert, nil
	}

	now := time.Now()
	return issueAndPersist(certPath, keyPath, names, now.Add(-clockSkew), now.Add(validity))
}

// Fingerprint returns the uppercase, colon-separated hex SHA-256 digest of
// the certificate's DER bytes, suitable for human comparison and for
// pinning by a client.
func Fingerprint(cert *x509.Certificate) string {
	sum := sha256.Sum256(cert.Raw)
	parts := make([]string, len(sum))
	for i, b := range sum {
		parts[i] = fmt.Sprintf("%02X", b)
	}
	return strings.Join(parts, ":")
}

// tryLoad attempts to load and validate a stored certificate/key pair. It
// returns ok=false (never an error) whenever the pair should simply be
// re-issued: missing, unreadable, malformed, expired, or missing one of the
// currently configured names.
func tryLoad(certPath, keyPath string, names []string) (tls.Certificate, bool) {
	cert, err := tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		return tls.Certificate{}, false
	}
	leaf := cert.Leaf
	if leaf == nil {
		leaf, err = x509.ParseCertificate(cert.Certificate[0])
		if err != nil {
			return tls.Certificate{}, false
		}
		cert.Leaf = leaf
	}

	now := time.Now()
	if now.Before(leaf.NotBefore) || now.After(leaf.NotAfter) {
		return tls.Certificate{}, false
	}
	if !coversAllNames(leaf, names) {
		return tls.Certificate{}, false
	}
	return cert, true
}

// coversAllNames reports whether cert's SANs include every one of names.
// Extra SANs on the certificate that are not in names do not disqualify it.
func coversAllNames(cert *x509.Certificate, names []string) bool {
	for _, name := range names {
		if ip := net.ParseIP(name); ip != nil {
			if !containsIP(cert.IPAddresses, ip) {
				return false
			}
			continue
		}
		if !containsString(cert.DNSNames, name) {
			return false
		}
	}
	return true
}

func containsIP(ips []net.IP, target net.IP) bool {
	for _, ip := range ips {
		if ip.Equal(target) {
			return true
		}
	}
	return false
}

func containsString(values []string, target string) bool {
	for _, v := range values {
		if v == target {
			return true
		}
	}
	return false
}

// issueAndPersist creates a new ECDSA P-256 self-signed certificate valid
// from notBefore to notAfter covering names, and writes it (and its
// private key) into certPath/keyPath, replacing whatever was there.
func issueAndPersist(certPath, keyPath string, names []string, notBefore, notAfter time.Time) (tls.Certificate, error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("selfsigned: generate key: %w", err)
	}

	serial, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("selfsigned: generate serial: %w", err)
	}

	template := &x509.Certificate{
		SerialNumber: serial,
		Subject:      pkix.Name{CommonName: names[0]},
		NotBefore:    notBefore,
		NotAfter:     notAfter,
		KeyUsage:     x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	for _, name := range names {
		if ip := net.ParseIP(name); ip != nil {
			template.IPAddresses = append(template.IPAddresses, ip)
		} else {
			template.DNSNames = append(template.DNSNames, name)
		}
	}

	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("selfsigned: create certificate: %w", err)
	}

	if err := savePair(certPath, keyPath, der, key); err != nil {
		return tls.Certificate{}, err
	}

	leaf, err := x509.ParseCertificate(der)
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("selfsigned: parse issued certificate: %w", err)
	}

	return tls.Certificate{
		Certificate: [][]byte{der},
		PrivateKey:  key,
		Leaf:        leaf,
	}, nil
}

// savePair writes the certificate and private key as PEM files. The key
// file is written with mode 0600 (owner-only), since it is a private key.
func savePair(certPath, keyPath string, der []byte, key *ecdsa.PrivateKey) error {
	certOut, err := os.OpenFile(certPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		return fmt.Errorf("selfsigned: open cert file: %w", err)
	}
	defer certOut.Close()
	if err := pem.Encode(certOut, &pem.Block{Type: "CERTIFICATE", Bytes: der}); err != nil {
		return fmt.Errorf("selfsigned: write cert file: %w", err)
	}
	if err := certOut.Close(); err != nil {
		return fmt.Errorf("selfsigned: close cert file: %w", err)
	}

	keyBytes, err := x509.MarshalECPrivateKey(key)
	if err != nil {
		return fmt.Errorf("selfsigned: marshal key: %w", err)
	}
	keyOut, err := os.OpenFile(keyPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return fmt.Errorf("selfsigned: open key file: %w", err)
	}
	defer keyOut.Close()
	if err := pem.Encode(keyOut, &pem.Block{Type: "EC PRIVATE KEY", Bytes: keyBytes}); err != nil {
		return fmt.Errorf("selfsigned: write key file: %w", err)
	}
	if err := keyOut.Close(); err != nil {
		return fmt.Errorf("selfsigned: close key file: %w", err)
	}
	// Ensure the mode is exactly 0600 even if the file already existed
	// with different permissions (O_CREATE does not change an existing
	// file's mode).
	if err := os.Chmod(keyPath, 0o600); err != nil {
		return fmt.Errorf("selfsigned: chmod key file: %w", err)
	}
	return nil
}
