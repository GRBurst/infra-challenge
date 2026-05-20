package main

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
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

func TestGetIPFromRequestFallsBackToRemoteAddr(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.RemoteAddr = "127.0.0.1:1234"
	if got, want := GetIPFromRequest(req), "127.0.0.1:1234"; got != want {
		t.Fatalf("GetIPFromRequest = %q, want %q", got, want)
	}
}

func TestSlogProducesJSON(t *testing.T) {
	var buf bytes.Buffer
	prev := logger
	logger = slog.New(slog.NewJSONHandler(&buf, nil))
	t.Cleanup(func() { logger = prev })

	logger.Info("greeting_served",
		slog.String("client_ip", "10.0.0.1"),
		slog.String("pod", "greeter-test"),
	)

	var entry map[string]any
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &entry); err != nil {
		t.Fatalf("log line is not valid JSON: %v\n%s", err, buf.String())
	}
	for _, key := range []string{"time", "level", "msg", "client_ip", "pod"} {
		if _, ok := entry[key]; !ok {
			t.Errorf("missing key %q in log entry: %v", key, entry)
		}
	}
	if entry["msg"] != "greeting_served" {
		t.Errorf("expected msg=greeting_served, got %v", entry["msg"])
	}
}

func TestHelloServerEmitsStructuredLog(t *testing.T) {
	t.Setenv("HOSTNAME", "local")
	var buf bytes.Buffer
	prev := logger
	logger = slog.New(slog.NewJSONHandler(&buf, nil))
	t.Cleanup(func() { logger = prev })

	_ = serveHello(t, "/")

	var entry map[string]any
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &entry); err != nil {
		t.Fatalf("HelloServer did not emit valid JSON: %v\n%s", err, buf.String())
	}
	if entry["msg"] != "greeting_served" {
		t.Errorf("expected msg=greeting_served, got %v", entry["msg"])
	}
	if entry["client_ip"] != "127.0.0.1:1234" {
		t.Errorf("expected client_ip=127.0.0.1:1234, got %v", entry["client_ip"])
	}
	if entry["pod"] != "local" {
		t.Errorf("expected pod=local, got %v", entry["pod"])
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
