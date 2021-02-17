#!/bin/bash
mvn install
docker build . -t asf-registry.cloudzcp.io/awesome-test/awesome-product-service:0.1.0
docker push asf-registry.cloudzcp.io/awesome-test/awesome-product-service:0.1.0
