package selfsigned

import (
	"net"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"
)

func TestLoadOrIssue_FirstCallIssuesAndPersists(t *testing.T) {
	dir := t.TempDir()
	cert, err := LoadOrIssue(dir, []string{"localhost", "127.0.0.1"})
	if err != nil {
		t.Fatalf("LoadOrIssue: %v", err)
	}
	if cert.Leaf == nil {
		t.Fatal("expected Leaf to be populated")
	}
	for _, name := range []string{filepath.Join(dir, certFileName), filepath.Join(dir, keyFileName)} {
		if _, err := os.Stat(name); err != nil {
			t.Errorf("expected %s to exist: %v", name, err)
		}
	}
}

func TestLoadOrIssue_SecondCallReusesSameFingerprint(t *testing.T) {
	dir := t.TempDir()
	names := []string{"localhost", "127.0.0.1"}

	first, err := LoadOrIssue(dir, names)
	if err != nil {
		t.Fatalf("first LoadOrIssue: %v", err)
	}
	second, err := LoadOrIssue(dir, names)
	if err != nil {
		t.Fatalf("second LoadOrIssue: %v", err)
	}

	fp1 := Fingerprint(first.Leaf)
	fp2 := Fingerprint(second.Leaf)
	if fp1 != fp2 {
		t.Errorf("fingerprint changed across restarts: %s != %s", fp1, fp2)
	}
}

func TestLoadOrIssue_ExpiredCertIsReissued(t *testing.T) {
	dir := t.TempDir()
	names := []string{"localhost"}
	certPath := filepath.Join(dir, certFileName)
	keyPath := filepath.Join(dir, keyFileName)

	past := time.Now().Add(-48 * time.Hour)
	expired, err := issueAndPersist(certPath, keyPath, names, past.Add(-time.Hour), past)
	if err != nil {
		t.Fatalf("issueAndPersist (expired): %v", err)
	}

	reissued, err := LoadOrIssue(dir, names)
	if err != nil {
		t.Fatalf("LoadOrIssue: %v", err)
	}

	if Fingerprint(reissued.Leaf) == Fingerprint(expired.Leaf) {
		t.Error("expected expired certificate to be replaced with a new fingerprint")
	}
	if !time.Now().Before(reissued.Leaf.NotAfter) {
		t.Error("reissued certificate should not be expired")
	}
}

func TestLoadOrIssue_NewNameForcesReissue(t *testing.T) {
	dir := t.TempDir()

	first, err := LoadOrIssue(dir, []string{"localhost"})
	if err != nil {
		t.Fatalf("first LoadOrIssue: %v", err)
	}

	second, err := LoadOrIssue(dir, []string{"localhost", "extra.example.com"})
	if err != nil {
		t.Fatalf("second LoadOrIssue: %v", err)
	}

	if Fingerprint(second.Leaf) == Fingerprint(first.Leaf) {
		t.Error("expected adding a name to force re-issuance with a new fingerprint")
	}
	if !containsString(second.Leaf.DNSNames, "extra.example.com") {
		t.Errorf("reissued cert DNSNames = %v, want to include extra.example.com", second.Leaf.DNSNames)
	}
}

func TestLoadOrIssue_IPNameGoesToIPAddresses(t *testing.T) {
	dir := t.TempDir()
	cert, err := LoadOrIssue(dir, []string{"127.0.0.1", "example.com"})
	if err != nil {
		t.Fatalf("LoadOrIssue: %v", err)
	}

	if len(cert.Leaf.IPAddresses) != 1 || !cert.Leaf.IPAddresses[0].Equal(net.ParseIP("127.0.0.1")) {
		t.Errorf("IPAddresses = %v, want [127.0.0.1]", cert.Leaf.IPAddresses)
	}
	if containsString(cert.Leaf.DNSNames, "127.0.0.1") {
		t.Error("IP-valued name must not appear in DNSNames")
	}
	if !containsString(cert.Leaf.DNSNames, "example.com") {
		t.Errorf("DNSNames = %v, want to include example.com", cert.Leaf.DNSNames)
	}
}

func TestLoadOrIssue_KeyFileMode0600(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("POSIX file mode bits are not meaningfully enforced on Windows")
	}
	dir := t.TempDir()
	if _, err := LoadOrIssue(dir, []string{"localhost"}); err != nil {
		t.Fatalf("LoadOrIssue: %v", err)
	}
	info, err := os.Stat(filepath.Join(dir, keyFileName))
	if err != nil {
		t.Fatalf("stat key file: %v", err)
	}
	if mode := info.Mode().Perm(); mode != 0o600 {
		t.Errorf("key file mode = %v, want 0600", mode)
	}
}
