package main

import (
	"fmt"
	"net/http"
	"os"
)

const maxTextInjectionBytes = 256

func main() {
	fmt.Println("Hivemind's Go Greeter")
	fmt.Println("You are running the service with this tag: ", os.Getenv("HELLO_TAG"))
	http.HandleFunc("/", HelloServer)
	http.ListenAndServe(":8080", nil)
}

func HelloServer(w http.ResponseWriter, r *http.Request) {
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
	fmt.Println(fmtStr)
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
