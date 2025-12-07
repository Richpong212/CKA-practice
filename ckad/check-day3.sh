#!/bin/bash
# CKAD Day 3 Checker - Services, ExternalName, Selectors

PASSED=0
TOTAL=4

green()  { printf "\e[32m%s\e[0m\n" "$1"; }
red()    { printf "\e[31m%s\e[0m\n" "$1"; }

pass() { local q="$1"; shift; green "Q$q: PASS - $*"; PASSED=$((PASSED+1)); }
fail() { local q="$1"; shift; red "Q$q: FAIL - $*"; }

# 3.1 web-frontend-svc ClusterIP
check_q31() {
  local ok=1
  local type sel_app port tport

  type=$(kubectl get svc web-frontend-svc -n day3-svc -o jsonpath='{.spec.type}' 2>/dev/null)
  sel_app=$(kubectl get svc web-frontend-svc -n day3-svc -o jsonpath='{.spec.selector.app}' 2>/dev/null)
  port=$(kubectl get svc web-frontend-svc -n day3-svc -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  tport=$(kubectl get svc web-frontend-svc -n day3-svc -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)

  [[ "$type"    != "ClusterIP"      ]] && ok=0
  [[ "$sel_app" != "web-frontend"   ]] && ok=0
  [[ "$port"    != "80"             ]] && ok=0
  [[ "$tport"   != "80"             ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "3.1" "web-frontend-svc correctly configured as ClusterIP"
  else
    fail "3.1" "web-frontend-svc type/selector/ports not correct"
  fi
}

# 3.2 api-backend-svc NodePort
check_q32() {
  local ok=1
  local type sel_app port tport np

  type=$(kubectl get svc api-backend-svc -n day3-svc -o jsonpath='{.spec.type}' 2>/dev/null)
  sel_app=$(kubectl get svc api-backend-svc -n day3-svc -o jsonpath='{.spec.selector.app}' 2>/dev/null)
  port=$(kubectl get svc api-backend-svc -n day3-svc -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  tport=$(kubectl get svc api-backend-svc -n day3-svc -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
  np=$(kubectl get svc api-backend-svc -n day3-svc -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

  [[ "$type"    != "NodePort"      ]] && ok=0
  [[ "$sel_app" != "api-backend"   ]] && ok=0
  [[ "$port"    != "3000"          ]] && ok=0
  [[ "$tport"   != "3000"          ]] && ok=0
  [[ -z "$np"   ]] && ok=0  # must have some nodePort

  if [[ $ok -eq 1 ]]; then
    pass "3.2" "api-backend-svc correctly configured as NodePort"
  else
    fail "3.2" "api-backend-svc type/selector/ports not correct"
  fi
}

# 3.3 mysql-ext ExternalName
check_q33() {
  local ok=1
  local type ename

  type=$(kubectl get svc mysql-ext -n day3-svc -o jsonpath='{.spec.type}' 2>/dev/null)
  ename=$(kubectl get svc mysql-ext -n day3-svc -o jsonpath='{.spec.externalName}' 2>/dev/null)

  [[ "$type"  != "ExternalName"         ]] && ok=0
  [[ "$ename" != "db.example.internal"  ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "3.3" "mysql-ext correctly configured as ExternalName"
  else
    fail "3.3" "mysql-ext type/externalName incorrect"
  fi
}

# 3.4 broken-api-svc selector fix
check_q34() {
  local sel_app
  sel_app=$(kubectl get svc broken-api-svc -n day3-svc -o jsonpath='{.spec.selector.app}' 2>/dev/null)

  if [[ "$sel_app" == "api-backend" ]]; then
    pass "3.4" "broken-api-svc selector correctly changed to app=api-backend"
  else
    fail "3.4" "broken-api-svc selector still incorrect"
  fi
}

echo "=== Day 3 Check: Services & Selectors ==="
check_q31
check_q32
check_q33
check_q34

echo "================================"
echo "Passed: $PASSED / $TOTAL"
PCT=$(( PASSED * 100 / TOTAL ))
echo "Score: ${PCT}%"
