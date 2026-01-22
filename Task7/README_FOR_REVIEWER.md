# Task 7: Аудит безопасности подов с PodSecurity и OPA Gatekeeper

## Шаг 1: Создание namespace с PodSecurity

```bash
kubectl apply -f 01-create-namespace.yaml
```

Namespace `audit-zone` создаётся с уровнем безопасности `restricted`, который:

- Запрещает privileged контейнеры
- Требует runAsNonRoot
- Запрещает hostPath volumes
- Требует dropping capabilities

## Шаг 2: Установка OPA Gatekeeper

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
```

Дождитесь готовности подов:

```bash
kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=120s
```

## Шаг 3: Применение ConstraintTemplates

```bash
kubectl apply -f gatekeeper/constraint-templates/
```

ConstraintTemplates определяют правила безопасности:

- **privileged.yaml** — запрещает `privileged: true`
- **hostpath.yaml** — запрещает `hostPath` volumes
- **runasnonroot.yaml** — требует `runAsNonRoot: true` и `readOnlyRootFilesystem: true`

## Шаг 4: Применение Constraints

```bash
kubectl apply -f gatekeeper/constraints/
```

Constraints применяют шаблоны к namespace `audit-zone`.

## Шаг 5: Проверка блокировки небезопасных манифестов

### Тест 1: Privileged контейнер

```bash
kubectl apply -f insecure-manifests/01-privileged-pod.yaml
```

**Ожидаемый результат**: Запрос отклонён с сообщением о нарушении политики.

### Тест 2: HostPath volume

```bash
kubectl apply -f insecure-manifests/02-hostpath-pod.yaml
```

**Ожидаемый результат**: Запрос отклонён из-за использования hostPath.

### Тест 3: Root пользователь

```bash
kubectl apply -f insecure-manifests/03-root-user-pod.yaml
```

**Ожидаемый результат**: Запрос отклонён из-за отсутствия runAsNonRoot.

## Шаг 6: Развёртывание безопасных подов

```bash
kubectl apply -f secure-manifests/
```

Все три безопасных манифеста должны успешно развернуться:

```bash
kubectl get pods -n audit-zone
```

## Шаг 7: Автоматическая проверка

### Проверка работы Admission Controllers

```bash
cd verify
chmod +x verify-admission.sh
./verify-admission.sh
```

Скрипт проверяет:

- Существование namespace audit-zone
- Установку Gatekeeper
- Наличие ConstraintTemplates и Constraints
- Блокировку небезопасных манифестов
- Валидность безопасных манифестов

### Валидация безопасности подов

```bash
chmod +x validate-security.sh
./validate-security.sh
```

Скрипт анализирует все поды в `audit-zone` и проверяет:

- Отсутствие privileged контейнеров
- Наличие runAsNonRoot: true
- Наличие readOnlyRootFilesystem: true
- Отсутствие hostPath volumes
- Запрет allowPrivilegeEscalation
- Сброс capabilities

## Проверка результатов

### 1. PodSecurity Admission работает

```bash
# Попытка создать privileged под
kubectl apply -f insecure-manifests/01-privileged-pod.yaml
# Ожидается: Error from server (Forbidden): error when creating...
```

### 2. Gatekeeper блокирует нарушения

```bash
# Проверка статуса constraints
kubectl get constraints
```

### 3. Безопасные поды развёрнуты

```bash
kubectl get pods -n audit-zone
# Ожидается: pod-secure-1, pod-secure-2, pod-secure-3 в статусе Running
```

### 4. Валидация безопасности

```bash
cd verify
./validate-security.sh
# Ожидается: все проверки пройдены (зелёные галочки)
```

## Устранение неполадок

### PodSecurity не блокирует поды

Проверьте labels namespace:

```bash
kubectl get namespace audit-zone -o yaml | grep pod-security
```

### Gatekeeper не работает

Проверьте статус подов:

```bash
kubectl get pods -n gatekeeper-system
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

### Constraints не применяются

Проверьте статус constraints:

```bash
kubectl get k8spspprivilegedcontainer psp-privileged-container -o yaml
kubectl get k8spsphostfilesystem psp-host-filesystem -o yaml
kubectl get k8spsprunasnonroot psp-run-as-non-root -o yaml
```

## Очистка

```bash
# Удаление подов
kubectl delete pods -n audit-zone --all

# Удаление constraints
kubectl delete -f gatekeeper/constraints/

# Удаление constraint templates
kubectl delete -f gatekeeper/constraint-templates/

# Удаление namespace
kubectl delete namespace audit-zone

# Удаление Gatekeeper (опционально)
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
```
