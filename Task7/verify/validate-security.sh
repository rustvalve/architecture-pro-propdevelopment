#!/bin/bash

# Скрипт для валидации безопасности подов в namespace audit-zone

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="${1:-audit-zone}"

echo "=== Валидация безопасности подов в namespace $NAMESPACE ==="
echo ""

# Проверка подов
PODS=$(kubectl get pods -n "$NAMESPACE" -o json 2>/dev/null)

if [ -z "$PODS" ] || [ "$(echo "$PODS" | jq '.items | length')" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Поды не найдены в namespace $NAMESPACE${NC}"
    exit 0
fi

echo "Найдено подов: $(echo "$PODS" | jq '.items | length')"
echo ""

# Проверка каждого пода
echo "$PODS" | jq -r '.items[] | @json' | while read -r pod; do
    POD_NAME=$(echo "$pod" | jq -r '.metadata.name')
    echo "${YELLOW}Под: $POD_NAME${NC}"
    echo "---"
    
    # Проверка 1: Privileged
    PRIVILEGED=$(echo "$pod" | jq -r '.spec.containers[] | select(.securityContext.privileged == true) | .name' 2>/dev/null)
    if [ -n "$PRIVILEGED" ]; then
        echo -e "${RED}✗ Privileged контейнеры: $PRIVILEGED${NC}"
    else
        echo -e "${GREEN}✓ Нет privileged контейнеров${NC}"
    fi
    
    # Проверка 2: RunAsNonRoot
    RUN_AS_NON_ROOT=$(echo "$pod" | jq -r '.spec.securityContext.runAsNonRoot // false')
    if [ "$RUN_AS_NON_ROOT" = "true" ]; then
        echo -e "${GREEN}✓ RunAsNonRoot: true${NC}"
    else
        echo -e "${RED}✗ RunAsNonRoot: false или не установлено${NC}"
    fi
    
    # Проверка 3: ReadOnlyRootFilesystem
    READONLY_COUNT=$(echo "$pod" | jq '[.spec.containers[] | select(.securityContext.readOnlyRootFilesystem == true)] | length')
    TOTAL_COUNT=$(echo "$pod" | jq '.spec.containers | length')
    if [ "$READONLY_COUNT" -eq "$TOTAL_COUNT" ]; then
        echo -e "${GREEN}✓ ReadOnlyRootFilesystem: true для всех контейнеров${NC}"
    else
        echo -e "${RED}✗ ReadOnlyRootFilesystem: не установлено для всех контейнеров ($READONLY_COUNT/$TOTAL_COUNT)${NC}"
    fi
    
    # Проверка 4: HostPath
    HOSTPATH=$(echo "$pod" | jq -r '.spec.volumes[]? | select(.hostPath) | .name' 2>/dev/null)
    if [ -n "$HOSTPATH" ]; then
        echo -e "${RED}✗ HostPath volumes: $HOSTPATH${NC}"
    else
        echo -e "${GREEN}✓ Нет hostPath volumes${NC}"
    fi
    
    # Проверка 5: AllowPrivilegeEscalation
    PRIV_ESC=$(echo "$pod" | jq -r '.spec.containers[] | select(.securityContext.allowPrivilegeEscalation != false) | .name' 2>/dev/null)
    if [ -n "$PRIV_ESC" ]; then
        echo -e "${RED}✗ AllowPrivilegeEscalation не запрещено: $PRIV_ESC${NC}"
    else
        echo -e "${GREEN}✓ AllowPrivilegeEscalation: false для всех контейнеров${NC}"
    fi
    
    # Проверка 6: Capabilities
    NO_CAPS=$(echo "$pod" | jq -r '.spec.containers[] | select(.securityContext.capabilities.drop | contains(["ALL"])) | .name' 2>/dev/null)
    if [ -n "$NO_CAPS" ]; then
        echo -e "${GREEN}✓ Capabilities dropped: $NO_CAPS${NC}"
    else
        echo -e "${YELLOW}⚠️  Capabilities не сброшены для всех контейнеров${NC}"
    fi
    
    echo ""
done

echo "${GREEN}=== Валидация завершена ===${NC}"
