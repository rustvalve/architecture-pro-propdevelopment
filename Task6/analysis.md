# Отчёт по результатам анализа Kubernetes Audit Log

## Подозрительные события

1. Доступ к секретам:

   - Кто: minikube-user
   - Где:

   ```json
   "auditID": "b51c6368-5a8d-4cad-9af7-5e962047278e",
   "objectRef": {
      "resource": "secrets",
      "namespace": "kube-system",
      "apiVersion": "v1"
    }
   ```

   - Почему подозрительно:

   ```json
      "message": "secrets is forbidden: User \"system:serviceaccount:secure-ops:monitoring\" cannot list resource \"secrets\" in API group \"\" in the namespace \"kube-system\"",
   ```

2. Привилегированные поды:

   - Кто: minikube-user
   - Комментарий: пользователю успешно удалось создать привелегированный под.

   ```json
    "kubectl.kubernetes.io/last-applied-configuration": "{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{},\"name\":\"privileged-pod\",\"namespace\":\"secure-ops\"},\"spec\":{\"containers\":[{\"command\":[\"sleep\",\"3600\"],\"image\":\"alpine\",\"name\":\"pwn\",\"securityContext\":{\"privileged\":true}}],\"restartPolicy\":\"Never\"}}\n"
   ```

3. Использование kubectl exec в чужом поде:

   - Кто: minikube-user
   - Что делал:

   ```json
    "requestURI": "/api/v1/namespaces/kube-system/pods/coredns-66bc5c9577-x2ksq/exec?command=cat&command=%2Fetc%2Fresolv.conf&container=coredns&stderr=true&stdout=true",
   ```

4. Создание RoleBinding с правами cluster-admin:
   События не найдены

5. Удаление audit-policy.yaml:
   События не найдены

## Вывод

Каждое из подозрительных действий инициировал пользователь minikube-user. Исходя из из них можно сказать, что была предпринята попытка несанкционированного доступа к кластеру.
Кластер можно считать компрометированным, т.к. пользователю удалось успешно создать привелегированный под.
