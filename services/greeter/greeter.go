package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
)

const maxTextInjectionBytes = 256

// logger emits structured JSON to stdout so Fluent Bit / CloudWatch Logs can
// parse fields without log-line regex. Tests swap this for a buffer.
var logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))

type versionInfo struct {
	HelloTag  string `json:"helloTag"`
	BuildTime string `json:"buildTime"`
	Hostname  string `json:"hostname"`
}

func main() {
	logger.Info("greeter_starting", slog.String("hello_tag", os.Getenv("HELLO_TAG")))
	http.HandleFunc("/", HelloServer)
	http.HandleFunc("/healthz", HealthzHandler)
	http.HandleFunc("/version", VersionHandler)
	if err := http.ListenAndServe(":8080", nil); err != nil {
		logger.Error("server_exited", slog.String("err", err.Error()))
		os.Exit(1)
	}
}

func HealthzHandler(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func VersionHandler(w http.ResponseWriter, _ *http.Request) {
	v := versionInfo{
		HelloTag:  os.Getenv("HELLO_TAG"),
		BuildTime: os.Getenv("BUILD_TIME"),
		Hostname:  os.Getenv("HOSTNAME"),
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(v)
}

func HelloServer(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("X-Hello-Tag", os.Getenv("HELLO_TAG"))
	fmtStr := fmt.Sprintf("Hello, %s! I'm %s", GetIPFromRequest(r), os.Getenv("HOSTNAME"))
	if textInjection := r.URL.Query().Get("textInjection"); textInjection != "" {
		// textInjection is untrusted URL input. It is appended only to a
		// text/plain response, with nosniff set, so browsers render it as text
		// instead of executing markup.
		// Limit its size to reduce response and log amplification risk.
		textInjection = truncateStringBytes(textInjection, maxTextInjectionBytes)
		fmtStr = fmt.Sprintf("%s %s", fmtStr, textInjection)
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	logger.Info("greeting_served",
		slog.String("client_ip", GetIPFromRequest(r)),
		slog.String("pod", os.Getenv("HOSTNAME")),
	)
	fmt.Fprintln(w, fmtStr)
}

func GetIPFromRequest(r *http.Request) string {
	if fwd := r.Header.Get("x-forwarded-for"); fwd != "" {
		return fwd
	}

	return r.RemoteAddr
}

func truncateStringBytes(s string, maxBytes int) string {
	if maxBytes <= 0 {
		return ""
	}
	if len(s) <= maxBytes {
		return s
	}

	prev := 0
	for i := range s {
		if i == maxBytes {
			return s[:i]
		}
		if i > maxBytes {
			return s[:prev]
		}
		prev = i
	}

	return s[:prev]
}
