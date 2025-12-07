#!/bin/bash
# CKAD Day 2 Checker - SecurityContext, Probes, Resources, RBAC

PASSED=0
TOTAL=4

green()  { printf "\e[32m%s\e[0m\n" "$1"; }
red()    { printf "\e[31m%s\e[0m\n" "$1"; }

pass() { local q="$1"; shift; green "Q$q: PASS - $*"; PASSED=$((PASSED+1)); }
fail() { local q="$1"; shift; red "Q$q: FAIL - $*"; }

# 2.1 net-tool SecurityContext
check_q21() {
  local ok=1
  local runas cap

  runas=$(kubectl get deploy net-tool -n day2-sec \
    -o jsonpath='{.spec.template.spec.securityContext.runAsUser}' 2>/dev/null)
  cap=$(kubectl get deploy net-tool -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.add}' 2>/dev/null)

  [[ "$runas" != "1000" ]] && ok=0
  echo "$cap" | grep -q "NET_ADMIN" || ok=0

  if [[ $ok -eq 1 ]]; then
    pass "2.1" "net-tool has runAsUser=1000 and NET_ADMIN capability"
  else
    fail "2.1" "net-tool SecurityContext not configured correctly"
  fi
}

# 2.2 pay-api readiness + liveness
check_q22() {
  local ok=1
  local rpath rport rdelay lpath lport ldelay

  rpath=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
  rport=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null)
  rdelay=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.initialDelaySeconds}' 2>/dev/null)

  lpath=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null)
  lport=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}' 2>/dev/null)
  ldelay=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.initialDelaySeconds}' 2>/dev/null)

  [[ "$rpath"  != "/ready" ]] && ok=0
  [[ "$rport"  != "8080"  ]] && ok=0
  [[ "$rdelay" != "5"     ]] && ok=0

  [[ "$lpath"  != "/healthz" ]] && ok=0
  [[ "$lport"  != "8080"    ]] && ok=0
  [[ "$ldelay" != "10"      ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "2.2" "pay-api readiness/liveness probes configured correctly"
  else
    fail "2.2" "pay-api readiness or liveness probe incorrect"
  fi
}

# 2.3 pay-api resources
check_q23() {
  local ok=1
  local rcpu rmem lcpu lmem

  rcpu=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
  rmem=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
  lcpu=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
  lmem=$(kubectl get deploy pay-api -n day2-sec \
    -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)

  [[ "$rcpu" != "200m"   ]] && ok=0
  [[ "$rmem" != "128Mi"  ]] && ok=0
  [[ "$lcpu" != "500m"   ]] && ok=0
  [[ "$lmem" != "256Mi"  ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "2.3" "pay-api resources (requests/limits) set correctly"
  else
    fail "2.3" "pay-api resources not set as required"
  fi
}

# 2.4 RBAC for log-reader
check_q24() {
  local ok=1

  # SA exists
  kubectl get sa reader-sa -n day2-sec >/dev/null 2>&1 || ok=0

  # Role has verbs
  local verbs
  verbs=$(kubectl get role pod-reader -n day2-sec \
    -o jsonpath='{.rules[?(@.resources[0]=="pods")].verbs}' 2>/dev/null)
  echo "$verbs" | grep -q "get"   || ok=0
  echo "$verbs" | grep -q "list"  || ok=0
  echo "$verbs" | grep -q "watch" || ok=0

  # RoleBinding binds reader-sa
  local rb_sa
  rb_sa=$(kubectl get rolebinding pod-reader-rb -n day2-sec \
    -o jsonpath='{.subjects[0].name}' 2>/dev/null)
  [[ "$rb_sa" != "reader-sa" ]] && ok=0

  # Pod uses reader-sa
  local pod_sa
  pod_sa=$(kubectl get pod log-reader -n day2-sec \
    -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
  [[ "$pod_sa" != "reader-sa" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "2.4" "RBAC correctly configured for log-reader with reader-sa"
  else
    fail "2.4" "RBAC setup for log-reader is incomplete or incorrect"
  fi
}

echo "=== Day 2 Check: Security, Probes, RBAC ==="
check_q21
check_q22
check_q23
check_q24

echo "=================================="
echo "Passed: $PASSED / $TOTAL"
PCT=$(( PASSED * 100 / TOTAL ))
echo "Score: ${PCT}%"
