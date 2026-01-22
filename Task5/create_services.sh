#!/bin/bash

# Скрипт для создания 4 nginx сервисов в namespace prod-development

echo "Создание namespace prod-development..."
kubectl create namespace prod-development --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Создание сервисов..."

kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80 -n prod-development
kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80 -n prod-development
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80 -n prod-development
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80 -n prod-development

echo ""
echo "✓ Сервисы созданы!"
echo ""
echo "Проверка:"
kubectl get all -n prod-development
