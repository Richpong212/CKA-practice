#!/usr/bin/env bash
# CKAD 2025 – Trouble Spots Mock (10 Exercises) – Auto Checker

set -euo pipefail

BASE_DIR="${HOME}/ckad-mock10"

PASSED=0
TOTAL=10

green() { printf "\e[32m%s\e[0m\n" "$1"; }
red()   { printf "\e[31m%s\e[0m\n" "$1"; }

pass() { local q="$1"; shift; green "Q$q: PASS - $*"; PASSED=$((PASSED+1)); }
fail() { local q="$1"; shift; red   "Q$q: FAIL - $*"; }

# Q1: Ingress app-ing must route example.com/ -> backend-svc:80 (path=/ Prefix)
check_q1() {
  local ok=1
  local host path pt svc port
  host=$(kubectl get ing app-ing -n inglab -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
  path=$(kubectl get ing app-ing -n inglab -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null || echo "")
  pt=$(kubectl get ing app-ing -n inglab -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' 2>/dev/null || echo "")
  svc=$(kubectl get ing app-ing -n inglab -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || echo "")
  port=$(kubectl get ing app-ing -n inglab -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null || echo "")

  [[ "$host" != "example.com" ]] && ok=0
  [[ "$path" != "/" ]] && ok=0
  [[ "$pt" != "Prefix" ]] && ok=0
  [[ "$svc" != "backend-svc" ]] && ok=0
  [[ "$port" != "80" ]] && ok=0

  [[ $ok -eq 1 ]] && pass 1 "Ingress example.com/ -> backend-svc:80 (Prefix)" || fail 1 "Fix host/path/pathType/backend"
}

# Q2: web-svc selector must be app=web
check_q2() {
  local sel
  sel=$(kubectl get svc web-svc -n svclab -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "")
  [[ "$sel" == "web" ]] && pass 2 "web-svc selector app=web" || fail 2 "Service selector still wrong"
}

# Q3: Canary 20% with max 10 pods: stable=8, canary=2 (labels match, service selects app=api)
check_q3() {
  local ok=1
  local srep crep ssel csel svcsel
  srep=$(kubectl get deploy api-stable -n canarylab -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
  crep=$(kubectl get deploy api-canary -n canarylab -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
  ssel=$(kubectl get deploy api-stable -n canarylab -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null || echo "")
  csel=$(kubectl get deploy api-canary -n canarylab -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null || echo "")
  svcsel=$(kubectl get svc api-svc -n canarylab -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "")

  [[ "$srep" != "8" ]] && ok=0
  [[ "$crep" != "2" ]] && ok=0
  [[ "$ssel" != "api" ]] && ok=0
  [[ "$csel" != "api" ]] && ok=0
  [[ "$svcsel" != "api" ]] && ok=0

  [[ $ok -eq 1 ]] && pass 3 "Canary split stable=8, canary=2 (max 10) behind api-svc" || fail 3 "Set replicas to 8/2 and ensure svc selects app=api"
}

# Q4: RBAC #1: audit-agent deployment must use audit-sa and Role+RoleBinding allow list pods
check_q4() {
  local ok=1
  kubectl get sa audit-sa -n rbaclab >/dev/null 2>&1 || ok=0

  local sa
  sa=$(kubectl get deploy audit-agent -n rbaclab -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null || echo "")
  [[ "$sa" != "audit-sa" ]] && ok=0

  # role rules include pods + get/list/watch
  local res verbs
  res=$(kubectl get role audit-role -n rbaclab -o jsonpath='{.rules[0].resources}' 2>/dev/null || echo "")
  verbs=$(kubectl get role audit-role -n rbaclab -o jsonpath='{.rules[0].verbs}' 2>/dev/null || echo "")
  echo "$res" | grep -q "pods" || ok=0
  echo "$verbs" | grep -q "get" || ok=0
  echo "$verbs" | grep -q "list" || ok=0
  echo "$verbs" | grep -q "watch" || ok=0

  local rb
  rb=$(kubectl get rolebinding audit-rb -n rbaclab -o jsonpath='{.subjects[0].name}' 2>/dev/null || echo "")
  [[ "$rb" != "audit-sa" ]] && ok=0

  [[ $ok -eq 1 ]] && pass 4 "audit-agent RBAC fixed (audit-sa + role + rolebinding)" || fail 4 "RBAC not correct for audit-agent"
}

# Q5: RBAC #2: inspector pod must use inspector-sa and Role allows get/list configmaps
check_q5() {
  local ok=1
  kubectl get sa inspector-sa -n rbaclab >/dev/null 2>&1 || ok=0

  local sa
  sa=$(kubectl get pod inspector -n rbaclab -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null || echo "")
  [[ "$sa" != "inspector-sa" ]] && ok=0

  local res verbs
  res=$(kubectl get role inspector-role -n rbaclab -o jsonpath='{.rules[0].resources}' 2>/dev/null || echo "")
  verbs=$(kubectl get role inspector-role -n rbaclab -o jsonpath='{.rules[0].verbs}' 2>/dev/null || echo "")
  echo "$res" | grep -q "configmaps" || ok=0
  echo "$verbs" | grep -q "get" || ok=0
  echo "$verbs" | grep -q "list" || ok=0

  local rb
  rb=$(kubectl get rolebinding inspector-rb -n rbaclab -o jsonpath='{.subjects[0].name}' 2>/dev/null || echo "")
  [[ "$rb" != "inspector-sa" ]] && ok=0

  [[ $ok -eq 1 ]] && pass 5 "inspector RBAC fixed (configmaps get/list)" || fail 5 "RBAC not correct for inspector"
}

# Q6: NetPol label-only: set roles to frontend/backend/db and newpod must have BOTH labels role=frontend AND access=db (example)
check_q6() {
  local ok=1
  local f b d nr na
  f=$(kubectl get pod frontend -n netlab -o jsonpath='{.metadata.labels.role}' 2>/dev/null || echo "")
  b=$(kubectl get pod backend  -n netlab -o jsonpath='{.metadata.labels.role}' 2>/dev/null || echo "")
  d=$(kubectl get pod db      -n netlab -o jsonpath='{.metadata.labels.role}' 2>/dev/null || echo "")
  nr=$(kubectl get pod newpod -n netlab -o jsonpath='{.metadata.labels.role}' 2>/dev/null || echo "")
  na=$(kubectl get pod newpod -n netlab -o jsonpath='{.metadata.labels.access}' 2>/dev/null || echo "")

  [[ "$f" != "frontend" ]] && ok=0
  [[ "$b" != "backend" ]] && ok=0
  [[ "$d" != "db" ]] && ok=0
  [[ "$nr" != "frontend" ]] && ok=0
  [[ "$na" != "db" ]] && ok=0

  [[ $ok -eq 1 ]] && pass 6 "NetPol fixed via labels only (incl multi-label newpod)" || fail 6 "Labels not set correctly (do not edit policies)"
}

# Q7: CronJob quick-exit: container must exit after ~8s without sleep, and job created manually should Complete
check_q7() {
  local ok=1
  # Verify command contains SECONDS loop marker (we'll require keyword SECONDS)
  local args
  args=$(kubectl get cronjob quick-exit -n cronlab -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].args[0]}' 2>/dev/null || echo "")
  echo "$args" | grep -q "SECONDS" || ok=0

  # A manually-triggered job named quick-exit-manual must exist and complete
  kubectl get job quick-exit-manual -n cronlab >/dev/null 2>&1 || ok=0
  local comp
  comp=$(kubectl get job quick-exit-manual -n cronlab -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
  [[ "$comp" != "1" ]] && ok=0

  [[ $ok -eq 1 ]] && pass 7 "CronJob exits after ~8s (no sleep) + manual job completed" || fail 7 "CronJob/job not correct"
}

# Q8: broken-ingress.yaml must be applied successfully after fixing pathType to Prefix
check_q8() {
  local pt
  pt=$(kubectl get ing broken-ing -n inglab -o jsonpath='{.spec.rules[0].http.paths[0].pathType}' 2>/dev/null || echo "")
  [[ "$pt" == "Prefix" || "$pt" == "Exact" || "$pt" == "ImplementationSpecific" ]] \
    && pass 8 "broken-ing applied with valid pathType ($pt)" \
    || fail 8 "broken-ing not applied/fixed"
}

# Q9: LimitRange halved + payments deployment has explicit requests/limits
check_q9() {
  local ok=1
  local rq rc lq lc rm lm prq plq

  rq=$(kubectl get limitrange dev-limits -n resourcelab -o jsonpath='{.spec.limits[0].defaultRequest.cpu}' 2>/dev/null || echo "")
  rc=$(kubectl get limitrange dev-limits -n resourcelab -o jsonpath='{.spec.limits[0].default.cpu}' 2>/dev/null || echo "")
  rm=$(kubectl get limitrange dev-limits -n resourcelab -o jsonpath='{.spec.limits[0].defaultRequest.memory}' 2>/dev/null || echo "")
  lm=$(kubectl get limitrange dev-limits -n resourcelab -o jsonpath='{.spec.limits[0].default.memory}' 2>/dev/null || echo "")

  [[ "$rq" != "200m" ]] && ok=0
  [[ "$rc" != "400m" ]] && ok=0
  [[ "$rm" != "128Mi" ]] && ok=0
  [[ "$lm" != "256Mi" ]] && ok=0

  prq=$(kubectl get deploy payments -n resourcelab -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
  plq=$(kubectl get deploy payments -n resourcelab -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")
  [[ -z "$prq" || -z "$plq" ]] && ok=0

  [[ $ok -eq 1 ]] && pass 9 "LimitRange halved + payments resources set" || fail 9 "LimitRange/resources not correct"
}

# Q10: ResourceQuota requests halved to 1 CPU / 1Gi and report-api limits=2x requests
check_q10() {
  local ok=1
  local rqcpu rqmem
  rqcpu=$(kubectl get rq team-quota -n resourcelab -o jsonpath='{.spec.hard.requests\.cpu}' 2>/dev/null || echo "")
  rqmem=$(kubectl get rq team-quota -n resourcelab -o jsonpath='{.spec.hard.requests\.memory}' 2>/dev/null || echo "")
  [[ "$rqcpu" != "1" ]] && ok=0
  [[ "$rqmem" != "1Gi" ]] && ok=0

  local rcpu lcpu rmem lmem
  rcpu=$(kubectl get deploy report-api -n resourcelab -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
  lcpu=$(kubectl get deploy report-api -n resourcelab -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")
  rmem=$(kubectl get deploy report-api -n resourcelab -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")
  lmem=$(kubectl get deploy report-api -n resourcelab -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")

  # quick 2x checks for common values
  case "$rcpu:$lcpu" in
    100m:200m|200m:400m|250m:500m|300m:600m|400m:800m|500m:1|500m:1000m|1:2) : ;;
    *) ok=0 ;;
  esac
  case "$rmem:$lmem" in
    64Mi:128Mi|128Mi:256Mi|256Mi:512Mi|512Mi:1Gi|1Gi:2Gi) : ;;
    *) ok=0 ;;
  esac

  [[ $ok -eq 1 ]] && pass 10 "Quota halved + limits=2x requests on report-api" || fail 10 "Quota/resources not correct"
}

echo "=== CKAD Mock10 Checker ==="
check_q1
check_q2
check_q3
check_q4
check_q5
check_q6
check_q7
check_q8
check_q9
check_q10
echo "=========================="
echo "Passed: $PASSED / $TOTAL"
echo "Score: $(( PASSED * 100 / TOTAL ))%"
