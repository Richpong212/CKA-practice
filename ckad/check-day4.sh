#!/bin/bash
# CKAD Day 4 Checker - Ingress & NetworkPolicies

PASSED=0
TOTAL=4

green()  { printf "\e[32m%s\e[0m\n" "$1"; }
red()    { printf "\e[31m%s\e[0m\n" "$1"; }

pass() { local q="$1"; shift; green "Q$q: PASS - $*"; PASSED=$((PASSED+1)); }
fail() { local q="$1"; shift; red "Q$q: FAIL - $*"; }

# 4.1 shop-ing Ingress fix
check_q41() {
  local ok=1
  local host svc port

  host=$(kubectl get ingress shop-ing -n day4-net \
    -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
  svc=$(kubectl get ingress shop-ing -n day4-net \
    -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
  port=$(kubectl get ingress shop-ing -n day4-net \
    -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)

  [[ "$host" != "shop.example.com"     ]] && ok=0
  [[ "$svc"  != "shop-frontend-svc"    ]] && ok=0
  [[ "$port" != "80"                   ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "4.1" "shop-ing correctly routes shop.example.com/ -> shop-frontend-svc:80"
  else
    fail "4.1" "shop-ing host/service/port not correct"
  fi
}

# 4.2 shop-api-ing Ingress
check_q42() {
  local ok=1
  local host path ptype svc port

  host=$(kubectl get ingress shop-api-ing -n day4-net \
    -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
  path=$(kubectl get ingress shop-api-ing -n day4-net \
    -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
  ptype=$(kubectl get ingress shop-api-ing -n day4-net \
    -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' 2>/dev/null)
  svc=$(kubectl get ingress shop-api-ing -n day4-net \
    -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
  port=$(kubectl get ingress shop-api-ing -n day4-net \
    -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)

  [[ "$host"  != "api.shop.example.com" ]] && ok=0
  [[ "$path"  != "/api"                  ]] && ok=0
  [[ "$ptype" != "Prefix"                ]] && ok=0
  [[ "$svc"   != "shop-backend-svc"      ]] && ok=0
  [[ "$port"  != "3000"                  ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "4.2" "shop-api-ing correctly routes api.shop.example.com/api -> shop-backend-svc:3000"
  else
    fail "4.2" "shop-api-ing not configured as required"
  fi
}

# 4.3 frontend/backend/db role labels
check_q43() {
  local ok=1
  local fr br dr

  fr=$(kubectl get pod frontend -n day4-net -o jsonpath='{.metadata.labels.role}' 2>/dev/null)
  br=$(kubectl get pod backend  -n day4-net -o jsonpath='{.metadata.labels.role}' 2>/dev/null)
  dr=$(kubectl get pod db       -n day4-net -o jsonpath='{.metadata.labels.role}' 2>/dev/null)

  [[ "$fr" != "frontend" ]] && ok=0
  [[ "$br" != "backend"  ]] && ok=0
  [[ "$dr" != "db"       ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "4.3" "frontend/backend/db labels match expected roles for NetworkPolicies"
  else
    fail "4.3" "frontend/backend/db labels not correctly set"
  fi
}

# 4.4 auth labels
check_q44() {
  local ok=1
  local role env

  role=$(kubectl get pod auth -n day4-net -o jsonpath='{.metadata.labels.role}' 2>/dev/null)
  env=$(kubectl get pod auth -n day4-net -o jsonpath='{.metadata.labels.env}' 2>/dev/null)

  [[ "$role" != "auth" ]] && ok=0
  [[ "$env"  != "prod" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "4.4" "auth pod has labels role=auth, env=prod for auth NPs"
  else
    fail "4.4" "auth pod labels not correctly set"
  fi
}

echo "=== Day 4 Check: Ingress & NetworkPolicies ==="
check_q41
check_q42
check_q43
check_q44

echo "======================================"
echo "Passed: $PASSED / $TOTAL"
PCT=$(( PASSED * 100 / TOTAL ))
echo "Score: ${PCT}%"

