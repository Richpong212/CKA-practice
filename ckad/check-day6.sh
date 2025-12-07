#!/bin/bash
# CKAD Day 6 Checker - Jobs, CronJobs, InitContainers

PASSED=0
TOTAL=4

green()  { printf "\e[32m%s\e[0m\n" "$1"; }
red()    { printf "\e[31m%s\e[0m\n" "$1"; }

pass() { local q="$1"; shift; green "Q$q: PASS - $*"; PASSED=$((PASSED+1)); }
fail() { local q="$1"; shift; red "Q$q: FAIL - $*"; }

# 6.1 hello-job
check_q61() {
  local ok=1
  local image

  image=$(kubectl get job hello-job -n day6-jobs \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)

  [[ "$image" != "busybox" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "6.1" "hello-job created with busybox image"
  else
    fail "6.1" "hello-job missing or image not busybox"
  fi
}

# 6.2 ping-cron
check_q62() {
  local ok=1
  local schedule image

  schedule=$(kubectl get cronjob ping-cron -n day6-jobs \
    -o jsonpath='{.spec.schedule}' 2>/dev/null)
  image=$(kubectl get cronjob ping-cron -n day6-jobs \
    -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' 2>/dev/null)

  [[ "$schedule" != "*/3 * * * *" ]] && ok=0
  [[ "$image"    != "busybox"    ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "6.2" "ping-cron created with correct schedule and image"
  else
    fail "6.2" "ping-cron schedule or image incorrect"
  fi
}

# 6.3 batch-workers
check_q63() {
  local ok=1
  local schedule comps parall backoff image

  schedule=$(kubectl get cronjob batch-workers -n day6-jobs \
    -o jsonpath='{.spec.schedule}' 2>/dev/null)
  comps=$(kubectl get cronjob batch-workers -n day6-jobs \
    -o jsonpath='{.spec.jobTemplate.spec.completions}' 2>/dev/null)
  parall=$(kubectl get cronjob batch-workers -n day6-jobs \
    -o jsonpath='{.spec.jobTemplate.spec.parallelism}' 2>/dev/null)
  backoff=$(kubectl get cronjob batch-workers -n day6-jobs \
    -o jsonpath='{.spec.jobTemplate.spec.backoffLimit}' 2>/dev/null)
  image=$(kubectl get cronjob batch-workers -n day6-jobs \
    -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' 2>/dev/null)

  [[ "$schedule" != "*/5 * * * *" ]] && ok=0
  [[ "$comps"    != "5"          ]] && ok=0
  [[ "$parall"   != "2"          ]] && ok=0
  [[ "$backoff"  != "4"          ]] && ok=0
  [[ "$image"    != "busybox"    ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "6.3" "batch-workers cronjob configured with correct schedule/completions/parallelism/backoffLimit"
  else
    fail "6.3" "batch-workers not configured as required"
  fi
}

# 6.4 init-script-pod
check_q64() {
  local ok=1
  local vol_type init_name mount_init mount_main

  vol_type=$(kubectl get pod init-script-pod -n day6-jobs \
    -o jsonpath='{.spec.volumes[0].emptyDir}' 2>/dev/null)
  init_name=$(kubectl get pod init-script-pod -n day6-jobs \
    -o jsonpath='{.spec.initContainers[0].name}' 2>/dev/null)
  mount_init=$(kubectl get pod init-script-pod -n day6-jobs \
    -o jsonpath='{.spec.initContainers[0].volumeMounts[0].mountPath}' 2>/dev/null)
  mount_main=$(kubectl get pod init-script-pod -n day6-jobs \
    -o jsonpath='{.spec.containers[0].volumeMounts[0].mountPath}' 2>/dev/null)

  [[ -z "$vol_type"         ]] && ok=0
  [[ "$init_name" != "init" ]] && ok=0
  [[ "$mount_init" != "/scripts" ]] && ok=0
  [[ "$mount_main" != "/scripts" ]] && ok=0

  if [[ $ok -eq 1 ]]; then
    pass "6.4" "init-script-pod uses shared emptyDir with init + main container"
  else
    fail "6.4" "init-script-pod not correctly configured with initContainer + shared volume"
  fi
}

echo "=== Day 6 Check: Jobs, CronJobs, InitContainers ==="
check_q61
check_q62
check_q63
check_q64

echo "========================================="
echo "Passed: $PASSED / $TOTAL"
PCT=$(( PASSED * 100 / TOTAL ))
echo "Score: ${PCT}%"
