mvn clean install && ^
docker build . -t asf-registry.cloudzcp.io/awesome-test/awesome-payment-service:0.1.0 && ^
docker push asf-registry.cloudzcp.io/awesome-test/awesome-payment-service:0.1.0 && ^
kubectl apply -k overlay/dev/
