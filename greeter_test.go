package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHelloServerWithoutTextInjection(t *testing.T) {
	t.Setenv("HOSTNAME", "local")

	res := serveHello(t, "/")

	assertBody(t, res, "Hello, 127.0.0.1:1234! I'm local\n")
}

func TestHelloServerWithTextInjection(t *testing.T) {
	t.Setenv("HOSTNAME", "local")

	res := serveHello(t, "/?textInjection=welcome")

	assertBody(t, res, "Hello, 127.0.0.1:1234! I'm local welcome\n")
}

func TestHelloServerTreatsUnsafeLookingTextInjectionAsPlainText(t *testing.T) {
	t.Setenv("HOSTNAME", "local")

	res := serveHello(t, "/?textInjection=%3Cscript%3Ealert(1)%3C/script%3E")

	assertBody(t, res, "Hello, 127.0.0.1:1234! I'm local <script>alert(1)</script>\n")
	if got, want := res.Header.Get("Content-Type"), "text/plain; charset=utf-8"; got != want {
		t.Fatalf("Content-Type = %q, want %q", got, want)
	}
	if got, want := res.Header.Get("X-Content-Type-Options"), "nosniff"; got != want {
		t.Fatalf("X-Content-Type-Options = %q, want %q", got, want)
	}
}

func TestHelloServerUsesFirstRepeatedTextInjection(t *testing.T) {
	t.Setenv("HOSTNAME", "local")

	res := serveHello(t, "/?textInjection=first&textInjection=second")

	assertBody(t, res, "Hello, 127.0.0.1:1234! I'm local first\n")
}

func TestHelloServerTruncatesLongTextInjection(t *testing.T) {
	t.Setenv("HOSTNAME", "local")
	textInjection := strings.Repeat("a", maxTextInjectionBytes+1)

	res := serveHello(t, "/?textInjection="+textInjection)

	assertBody(t, res, "Hello, 127.0.0.1:1234! I'm local "+strings.Repeat("a", maxTextInjectionBytes)+"\n")
}

func TestTruncateStringBytesKeepsRuneBoundary(t *testing.T) {
	if got, want := truncateStringBytes("éé", 3), "é"; got != want {
		t.Fatalf("truncateStringBytes() = %q, want %q", got, want)
	}
}

func serveHello(t *testing.T, target string) *http.Response {
	t.Helper()

	req := httptest.NewRequest(http.MethodGet, target, nil)
	req.RemoteAddr = "127.0.0.1:1234"
	rec := httptest.NewRecorder()

	HelloServer(rec, req)

	return rec.Result()
}

func TestHealthzReturns200(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()
	HealthzHandler(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
}

func TestVersionReturnsJSON(t *testing.T) {
	t.Setenv("HELLO_TAG", "abc123")
	t.Setenv("BUILD_TIME", "2026-05-13T10:00:00Z")
	t.Setenv("HOSTNAME", "pod-xyz")
	req := httptest.NewRequest(http.MethodGet, "/version", nil)
	rec := httptest.NewRecorder()
	VersionHandler(rec, req)

	if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "application/json") {
		t.Fatalf("Content-Type = %q, want application/json…", ct)
	}
	var got struct {
		HelloTag, BuildTime, Hostname string
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.HelloTag != "abc123" || got.BuildTime != "2026-05-13T10:00:00Z" || got.Hostname != "pod-xyz" {
		t.Fatalf("got %+v", got)
	}
}

func TestHelloServerSetsXHelloTagHeader(t *testing.T) {
	t.Setenv("HELLO_TAG", "abc123")
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	HelloServer(rec, req)
	if got := rec.Header().Get("X-Hello-Tag"); got != "abc123" {
		t.Fatalf("X-Hello-Tag = %q, want abc123", got)
	}
}

func assertBody(t *testing.T, res *http.Response, want string) {
	t.Helper()

	body, err := io.ReadAll(res.Body)
	if err != nil {
		t.Fatalf("reading response body: %v", err)
	}
	if got := string(body); got != want {
		t.Fatalf("body = %q, want %q", got, want)
	}
}
