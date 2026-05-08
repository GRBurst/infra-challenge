package main

import (
	"io"
	"net/http"
	"net/http/httptest"
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

func serveHello(t *testing.T, target string) *http.Response {
	t.Helper()

	req := httptest.NewRequest(http.MethodGet, target, nil)
	req.RemoteAddr = "127.0.0.1:1234"
	rec := httptest.NewRecorder()

	HelloServer(rec, req)

	return rec.Result()
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
