#!/bin/bash

# Скрипт для анализа audit.log на предмет подозрительных действий

AUDIT_LOG="${1:-audit.log}"

if [ ! -f "$AUDIT_LOG" ]; then
    echo "❌ Файл $AUDIT_LOG не найден"
    exit 1
fi

echo "=== Анализ подозрительных действий в audit.log ==="
echo "Файл: $AUDIT_LOG"
echo ""

# Проверка наличия jq
if ! command -v jq &> /dev/null; then
    echo "❌ jq не установлен. Установите: brew install jq"
    exit 1
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Доступ к secrets от system:serviceaccount:monitoring
echo "${YELLOW}1. Доступ к secrets от system:serviceaccount:monitoring${NC}"
echo "---"
COUNT=$(jq -r 'select(.objectRef.resource=="secrets" and ((.impersonatedUser.username // .user.username) | contains("monitoring") or contains("system:serviceaccount:secure-ops")))' "$AUDIT_LOG" 2>/dev/null | jq -s 'length')
if [ "$COUNT" -gt 0 ]; then
    echo -e "${RED}⚠️  Найдено $COUNT подозрительных обращений к secrets${NC}"
    jq -r 'select(.objectRef.resource=="secrets" and ((.impersonatedUser.username // .user.username) | contains("monitoring") or contains("system:serviceaccount:secure-ops"))) | 
           "  [\(.stage)] \(.verb) \(.objectRef.resource)/\(.objectRef.name // "N/A") by \((.impersonatedUser.username // .user.username)) at \(.requestReceivedTimestamp)"' "$AUDIT_LOG" 2>/dev/null | head -10
else
    echo -e "${GREEN}✓ Не найдено${NC}"
fi
echo ""

# 2. Создание привилегированных подов
echo "${YELLOW}2. Создание привилегированных подов${NC}"
echo "---"
COUNT=$(jq -r 'select(.objectRef.resource=="pods" and .verb=="create" and (.requestObject.spec.containers[]? | .securityContext.privileged == true))' "$AUDIT_LOG" 2>/dev/null | jq -s 'length')
if [ "$COUNT" -gt 0 ]; then
    echo -e "${RED}⚠️  Найдено $COUNT попыток создания привилегированных подов${NC}"
    jq -r 'select(.objectRef.resource=="pods" and .verb=="create" and (.requestObject.spec.containers[]? | .securityContext.privileged == true)) | 
           "  [\(.stage)] Pod: \(.objectRef.name // "N/A") in namespace \(.objectRef.namespace // "N/A") by \(.user.username) at \(.requestReceivedTimestamp)"' "$AUDIT_LOG" 2>/dev/null | head -10
else
    echo -e "${GREEN}✓ Не найдено${NC}"
fi
echo ""

# 3. Использование kubectl exec в чужие поды
echo "${YELLOW}3. Использование kubectl exec в чужие поды${NC}"
echo "---"
# Exec логируется как GET /api/v1/namespaces/{ns}/pods/{name}/exec?command=...
COUNT=$(jq -r 'select(.requestURI | contains("/exec"))' "$AUDIT_LOG" 2>/dev/null | jq -s 'length')
if [ "$COUNT" -gt 0 ]; then
    echo -e "${RED}⚠️  Найдено $COUNT попыток exec в поды${NC}"
    jq -r 'select(.requestURI | contains("/exec")) | 
           "  [\(.stage)] exec в pod \(.objectRef.name // "N/A") в namespace \(.objectRef.namespace // "N/A") by \(.user.username) at \(.requestReceivedTimestamp)"' "$AUDIT_LOG" 2>/dev/null | head -10
else
    echo -e "${GREEN}✓ Не найдено${NC}"
fi
echo ""

# 4. Удаление или изменение audit-policy
echo "${YELLOW}4. Попытки удаления или изменения audit-policy${NC}"
echo "---"
COUNT=$(grep -i 'audit-policy' "$AUDIT_LOG" 2>/dev/null | wc -l | tr -d ' ')
if [ "$COUNT" -gt 0 ]; then
    echo -e "${RED}⚠️  Найдено $COUNT упоминаний audit-policy${NC}"
    grep -i 'audit-policy' "$AUDIT_LOG" 2>/dev/null | jq -r 'select(. != null) | 
           "  [\(.stage)] \(.verb) \(.objectRef.resource // "N/A") by \(.user.username // "N/A") at \(.requestReceivedTimestamp // "N/A")"' 2>/dev/null | head -10
else
    echo -e "${GREEN}✓ Не найдено${NC}"
fi
echo ""

# 5. Создание RoleBinding без согласования (эскалация привилегий)
echo "${YELLOW}5. Создание RoleBinding с cluster-admin (эскалация привилегий)${NC}"
echo "---"
# Ищем по API группе rbac.authorization.k8s.io или по requestURI, включая уровень Metadata
COUNT=$(jq -r 'select((.requestURI | contains("/apis/rbac.authorization.k8s.io")) or (.requestURI | contains("rolebindings")) or (.objectRef.resource == "rolebindings")) | select(.verb == "create" or .verb == "update" or .verb == "patch")' "$AUDIT_LOG" 2>/dev/null | jq -s 'length')
if [ "$COUNT" -gt 0 ]; then
    echo -e "${RED}⚠️  Найдено $COUNT операций с RoleBinding${NC}"
    # Показываем все операции с RoleBinding
    jq -r 'select((.requestURI | contains("/apis/rbac.authorization.k8s.io")) or (.requestURI | contains("rolebindings")) or (.objectRef.resource == "rolebindings")) | select(.verb == "create" or .verb == "update" or .verb == "patch") | 
           "  [\(.stage)] \(.verb) RoleBinding: \(.objectRef.name // .requestObject.metadata.name // "N/A") в namespace \(.objectRef.namespace // .requestObject.metadata.namespace // "N/A") by \(.user.username) at \(.requestReceivedTimestamp)"' "$AUDIT_LOG" 2>/dev/null | head -10
    # Проверяем, есть ли cluster-admin
    ADMIN_COUNT=$(jq -r 'select((.requestURI | contains("/apis/rbac.authorization.k8s.io")) or (.requestURI | contains("rolebindings"))) | select(.verb == "create" or .verb == "update") | select((.requestObject.roleRef.name? == "cluster-admin") or (.requestObject.roleRef.name? | contains("admin")) or (.requestObject.roleRef.kind? == "ClusterRole"))' "$AUDIT_LOG" 2>/dev/null | jq -s 'length')
    if [ "$ADMIN_COUNT" -gt 0 ]; then
        echo -e "${RED}  ⚠️  Из них $ADMIN_COUNT с admin правами!${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  RoleBinding не найден в логе. Возможно:${NC}"
    echo "   - Скрипт incidend-sim.sh не выполнился до конца"
    echo "   - Событие логируется на уровне Metadata (не RequestResponse)"
    echo "   - Лог был скопирован до создания RoleBinding"
    echo ""
    echo "   Проверьте вручную:"
    echo "   jq 'select(.requestURI | contains(\"rbac\") or contains(\"rolebinding\"))' $AUDIT_LOG"
fi
echo ""

# Сохранение подозрительных событий в JSON файл (только пункты 1-5, по одному событию на пункт)
OUTPUT_FILE="audit-extract.json"
echo "${YELLOW}=== Сохранение подозрительных событий (пункты 1-5) ===${NC}"
echo "Сбор всех подозрительных событий..."

# Собираем события по категориям отдельно, затем объединяем
# Используем jq для фильтрации и сохранения JSON объектов

# 1. Доступ к secrets от monitoring (GET или LIST на secrets в kube-system с impersonation)
EVENT1=$(jq -c 'select(.objectRef.resource=="secrets" and .objectRef.namespace=="kube-system" and .impersonatedUser.username == "system:serviceaccount:secure-ops:monitoring" and (.verb == "get" or .verb == "list"))' "$AUDIT_LOG" 2>/dev/null | head -n 1)

# 2. Создание привилегированного пода (CREATE pod с именем "privileged-pod" и privileged: true)
EVENT2=$(jq -c 'select(.objectRef.resource=="pods" and .verb=="create" and .objectRef.name=="privileged-pod" and (.requestObject.spec.containers[]? | .securityContext.privileged == true))' "$AUDIT_LOG" 2>/dev/null | head -n 1)

# 3. Exec в поды (GET запрос с /exec в requestURI)
EVENT3=$(jq -c 'select(.requestURI | contains("/exec"))' "$AUDIT_LOG" 2>/dev/null | head -n 1)

# 4. Упоминания audit-policy (DELETE запрос на audit-policy)
# Команда kubectl delete -f пытается удалить файл, но это не ресурс Kubernetes
# Ищем DELETE запросы, которые могут относиться к audit-policy (если команда выполнилась)
EVENT4=$(jq -c 'select(.verb == "delete" and ((.requestURI? | type == "string" and contains("audit-policy")) or (.objectRef.name? | type == "string" and contains("audit-policy"))))' "$AUDIT_LOG" 2>/dev/null | head -n 1)

# 5. Создание RoleBinding с cluster-admin (CREATE RoleBinding с cluster-admin в roleRef)
# Ищем в namespace secure-ops, где создается escalate-binding
EVENT5=$(jq -c 'select(.objectRef.resource == "rolebindings" and .verb == "create" and .requestObject.roleRef.name == "cluster-admin")' "$AUDIT_LOG" 2>/dev/null | head -n 1)

# Объединяем все события в массив, убираем пустые и дубликаты
RESULT="[]"
[ -n "$EVENT1" ] && [ ${#EVENT1} -gt 0 ] && RESULT=$(echo "$RESULT" | jq ". + [$EVENT1]" 2>/dev/null || echo "$RESULT")
[ -n "$EVENT2" ] && [ ${#EVENT2} -gt 0 ] && RESULT=$(echo "$RESULT" | jq ". + [$EVENT2]" 2>/dev/null || echo "$RESULT")
[ -n "$EVENT3" ] && [ ${#EVENT3} -gt 0 ] && RESULT=$(echo "$RESULT" | jq ". + [$EVENT3]" 2>/dev/null || echo "$RESULT")
[ -n "$EVENT4" ] && [ ${#EVENT4} -gt 0 ] && RESULT=$(echo "$RESULT" | jq ". + [$EVENT4]" 2>/dev/null || echo "$RESULT")
[ -n "$EVENT5" ] && [ ${#EVENT5} -gt 0 ] && RESULT=$(echo "$RESULT" | jq ". + [$EVENT5]" 2>/dev/null || echo "$RESULT")

# Убираем дубликаты по auditID
echo "$RESULT" | jq 'unique_by(.auditID)' > "$OUTPUT_FILE" 2>/dev/null

EXTRACTED_COUNT=$(jq 'length' "$OUTPUT_FILE" 2>/dev/null || echo "0")

# Проверяем, что файл существует и содержит валидный JSON массив
if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    EXTRACTED_COUNT=$(jq 'length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
    if [ "$EXTRACTED_COUNT" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓ Сохранено $EXTRACTED_COUNT подозрительных событий в $OUTPUT_FILE${NC}"
    echo ""
    echo "Количество событий по типам:"
    echo "  - Secrets от monitoring: $(jq '[.[] | select(.objectRef.resource=="secrets" and .objectRef.namespace=="kube-system" and .impersonatedUser.username == "system:serviceaccount:secure-ops:monitoring")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")"
    echo "  - Привилегированные поды: $(jq '[.[] | select(.objectRef.resource=="pods" and .verb=="create" and .objectRef.name=="privileged-pod")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")"
    echo "  - Exec в поды: $(jq '[.[] | select(.requestURI? | contains("/exec"))] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")"
    echo "  - Audit-policy: $(jq '[.[] | select(.verb? == "delete" and ((.requestURI? | contains("audit-policy")) or (.objectRef.name? | contains("audit-policy"))))] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")"
    echo "  - RoleBinding: $(jq '[.[] | select(.objectRef.resource == "rolebindings" and .verb == "create" and .requestObject.roleRef.name == "cluster-admin")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")"
        echo ""
        echo "Просмотр файла:"
        echo "  cat $OUTPUT_FILE | jq '.'"
    else
        echo -e "${YELLOW}⚠️  Подозрительные события не найдены для сохранения${NC}"
        echo "[]" > "$OUTPUT_FILE"
    fi
else
    echo -e "${YELLOW}⚠️  Не удалось создать файл с событиями${NC}"
    echo "[]" > "$OUTPUT_FILE"
fi
echo ""
