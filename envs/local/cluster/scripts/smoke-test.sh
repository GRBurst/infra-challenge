#!/usr/bin/env bash
set -euo pipefail

CTX="k3d-infra-challenge"
NS="greeter"
PORT=8080

kubectl --context "$CTX" -n "$NS" rollout status deployment/greeter --timeout=120s

kubectl --context "$CTX" -n "$NS" port-forward svc/greeter "$PORT:8080" >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT
deadline=$(( SECONDS + 30 ))
until curl -sf "http://localhost:$PORT/healthz" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    echo "FAIL: greeter port-forward did not become reachable within 30s"; exit 1
  fi
  sleep 0.2
done

test "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:$PORT/healthz)" = "200"
curl -sI "http://localhost:$PORT/" | grep -iq '^x-hello-tag:'
test "$(curl -s http://localhost:$PORT/version | jq -r .helloTag)" != ""
curl -s "http://localhost:$PORT/?textInjection=hello" | grep -q hello

echo "smoke tests passed"
