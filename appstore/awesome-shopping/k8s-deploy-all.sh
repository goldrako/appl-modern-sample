#!/bin/bash
kubectl apply -k awesome-account-service/overlay/dev &&
kubectl apply -k awesome-bff-service/overlay/dev &&
kubectl apply -k awesome-cart-service/overlay/dev &&
kubectl apply -k awesome-order-service/overlay/dev &&
kubectl apply -k awesome-payment-service/overlay/dev &&
kubectl apply -k awesome-product-service/overlay/dev