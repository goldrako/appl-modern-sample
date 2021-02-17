# UNDER DEVELOPMENT
not ready to use
전체 형상을 하나로 만들고서 이를 dev, stg, prod로 나누기 위한 예시

# 1toN 과 차이점
각 마이크로서비스는 자기 완결적인 pod 생성/연동 및 service 연결을 위해 labels 및 matchLabels 항목을 상세히 관리해야 한다. 하나의 deployment를 가지고 마이크로서비스로 확장하는 구조에서는 overlay의 commonLabels 선언으로 자동으로 labels/matchLabels가 생성된다. 1to1 예시의 경우는 마이크로서비스 하나를 이루는 예를들어 `account.yaml` 내에서 deployment와 service를 선언하면서 필요한 labels, matchLabels, selector 등을 선언해서 사용해야 한다. 

## 한계점
복수의 마이크로서비스를 위한 형상은 1to1 에 맞지 않음. 공통요소를 일일이 손으로 코딩해주어야 하기에 역으로 반복적인 관리 요소가 늘어남. awesome-shopping과 같이 복수가 동일한 관리체계를 가지는 마이크로서비스에 대해서는 공통의 base를 가지고 복수의 마이크로서비스 overlay를 만드는 방식이 어울림. 

예) 공통패턴 주입을 위한 application.yaml 및 `spring.profiles.active` 를 주입하기 위해, 상이한 `metadata.name`을 가지는 deployment를 대상으로 일일이 patch 및 configMap생성등을 지시해야 함. 

1to1 방식은 quote-app 샘플과 같이 하나의 배포단위를 대상으로 공통된 관리방식을 주입해야 할 때 사용이 용이함. 각 세개의 앱을 구성함에 있어서 형상 생성이나 관리 방법이 서로 다르고, 다만 공통의 라벨 및 어노테이션을 관리한다던가, replicas/images 같은 값을 overlay/kustomization.yaml 하나의 파일로 수정하게 하는 식의 요구사항에 부합함.

상황에 따라 json patch의 multi-patch 기능을 이용하면 패치 횟수를 줄일수도 있음. 이는 overlay/v1/dev 에 `patches` 항목에 표현되어 있으나, 바로 다음의 configMapGenerator에서 모든 configMap에 common/pattern/application.yaml 을 추가하는 반복작업을 보여주기에 아쉬움. 다만 1toN 방식에서도 개별 마이크로서비스마다 공통 패턴 적용을 위해 configMapGenerator 옵션에서 동일한 파일을 참조케 하는것은 같음.