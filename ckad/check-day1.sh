#!/bin/bash
# CKAD Day 1 Checker - Environment, Secrets, ConfigMaps

PASSED=0
TOTAL=4

green()  { printf "\e[32m%s\e[0m\n" "$1"; }
red()    { printf "\e[31m%s\e[0m\n" "$1"; }

pass() {
  local q="$1"; shift
  green "Q$q: PASS - $*"
  PASSED=$((PASSED+1))
}

fail() {
  local q="$1"; shift
  red "Q$q: FAIL - $*"
}

# 1.1 Secret + envFrom.secretKeyRef for login-api
check_q11() {
  local ok=1

  # Secret exists & keys
  local user pass
  user=$(kubectl get secret db-credentials -n day1-env -o jsonpath='{.data.DB_USER}' 2>/dev/null)
  pass=$(kubectl get secret db-credentials -n day1-env -o jsonpath='{.data.DB_PASS}' 2>/dev/null)
  [[ -z "$user" || -z "$pass" ]] && ok=0

  # Deployment envs use secretKeyRef
  local su sp
  su=$(kubectl get deploy login-api -n day1-env \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_USER")].valueFrom.secretKeyRef.name}' 2>/dev/null)
  sp=$(kubectl get deploy login-api -n day1-env \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DB_PASS")].valueFrom.secretKeyRef.name}' 2>/dev/null)

  [[ "$su" != "db-credentials" ]] && ok=0
  [[ "$sp" != "db-credentials" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "1.1" "db-credentials + login-api envs correctly wired"
  else
    fail "1.1" "Secret and/or login-api envFrom.secretKeyRef not correct"
  fi
}

# 1.2 ConfigMap + envFrom on login-api
check_q12() {
  local ok=1

  # ConfigMap exists and has correct keys
  local log_level feature
  log_level=$(kubectl get configmap app-settings -n day1-env -o jsonpath='{.data.LOG_LEVEL}' 2>/dev/null)
  feature=$(kubectl get configmap app-settings -n day1-env -o jsonpath='{.data.FEATURE_X_ENABLED}' 2>/dev/null)

  [[ "$log_level" != "debug" ]] && ok=0
  [[ "$feature"  != "true"  ]] && ok=0

  # login-api envFrom includes app-settings
  local cmref
  cmref=$(kubectl get deploy login-api -n day1-env \
    -o jsonpath='{.spec.template.spec.containers[0].envFrom[?(@.configMapRef.name=="app-settings")].configMapRef.name}' 2>/dev/null)
  [[ "$cmref" != "app-settings" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "1.2" "app-settings ConfigMap + envFrom correctly configured on login-api"
  else
    fail "1.2" "ConfigMap or envFrom for login-api is incorrect"
  fi
}

# 1.3 ConfigMap mounted as volume
check_q13() {
  local ok=1

  # ConfigMap nginx-config exists and has index.html
  local idx
  idx=$(kubectl get configmap nginx-config -n day1-env -o jsonpath='{.data.index\.html}' 2>/dev/null)
  [[ -z "$idx" ]] && ok=0

  # Pod cm-volume-pod exists
  kubectl get pod cm-volume-pod -n day1-env >/dev/null 2>&1 || ok=0

  # Find any volume that uses nginx-config
  local cmname
  cmname=$(kubectl get pod cm-volume-pod -n day1-env \
    -o jsonpath='{.spec.volumes[?(@.configMap.name=="nginx-config")].name}' 2>/dev/null)

  [[ -z "$cmname" ]] && ok=0

  # Check that same volume is mounted at /usr/share/nginx/html
  local mount
  mount=$(kubectl get pod cm-volume-pod -n day1-env \
    -o jsonpath="{.spec.containers[0].volumeMounts[?(@.name==\"$cmname\")].mountPath}" 2>/dev/null)

  [[ "$mount" != "/usr/share/nginx/html" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "1.3" "cm-volume-pod correctly mounts nginx-config at /usr/share/nginx/html"
  else
    fail "1.3" "cm-volume-pod or nginx-config not configured correctly"
  fi
}


# 1.4 mix-api Deployment with secret + configmap env
check_q14() {
  local ok=1

  # Secret & ConfigMap exist with correct keys
  local api_key env
  api_key=$(kubectl get secret api-secret -n day1-env -o jsonpath='{.data.API_KEY}' 2>/dev/null)
  env=$(kubectl get configmap api-config -n day1-env -o jsonpath='{.data.API_ENV}' 2>/dev/null)
  [[ -z "$api_key" ]] && ok=0
  [[ "$env" != "staging" ]] && ok=0

  # Deployment mix-api env wiring
  local sref cref
  sref=$(kubectl get deploy mix-api -n day1-env \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="API_KEY")].valueFrom.secretKeyRef.name}' 2>/dev/null)
  cref=$(kubectl get deploy mix-api -n day1-env \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="API_ENV")].valueFrom.configMapKeyRef.name}' 2>/dev/null)

  [[ "$sref" != "api-secret" ]] && ok=0
  [[ "$cref" != "api-config" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "1.4" "mix-api uses api-secret + api-config correctly"
  else
    fail "1.4" "mix-api env wiring or supporting Secret/ConfigMap is incorrect"
  fi
}

echo "=== Day 1 Check: Environment, Secrets, ConfigMaps ==="
check_q11
check_q12
check_q13
check_q14

echo "==============================================="
echo "Passed: $PASSED / $TOTAL"
PCT=$(( PASSED * 100 / TOTAL ))
echo "Score: ${PCT}%"
