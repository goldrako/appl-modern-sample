# 공통 overlay 통한 공통 및 마이크로서비스 패턴 제공

```
kustomize build --load_restrictor none --enable_kyaml=false overlay/v1/dev/account
```

`/overlay/v1/dev/account/kustomization.yaml`에 상세 예제가 들어가 있음. 나머지 마이크로서비스는 단순한 형태.

## 상속 구조와 layering

```
base   -->   common overlay         -->   microservice 1 overlay   -->  deploying overlay
             common msa resource          microservice 2 overlay              ^
                                          microservice 3 overlay              |
                                                    ...            -----------+
```

* base
  * 컨설턴트 초기 셋업 영역
  * 프로젝트 특성에 따른 전체 공통형상 구축
* common overlay, common msa resource
  * TA/AA 구성 영역
  * 프로젝트 상세 상황에 맞는 설정 작성
  * DB/Queue등 백엔드 서비스 정의
  * 배포 환경(클러스터, dev/stg/prod등)에 맞는 백엔드 개별화
  * 마이크로서비스 패턴 활용시 정의되는 리소스 정의
* microservice overlay
  * 개발자 구성 영역
  * 마이크로서비스 전용의 설정 작성
  * 백엔드의 사용
  * 마이크로서비스 패턴 활용시 필요한 common msa resource 추가 참조
    * 문제) 개발자 영역의 kustomization.yaml에서 common msa resource 를 추가해야 함. 이에 대해 개발자 수정가능 영역에서 이와 같은 마이크로서비스 패턴관련 요소를 수정 못하게 하려면 microservice가 common resource를 추가하고자 할 때 마다 그에 맞는 별도의 common overlay를 구성하고 microservice overlay에 연결해야 함
    * 해결안) 형상 구성에 대해 완전 자동화(예를들어 msa dev fw/platform)가 가능할 경우 common overlay 및 common  msa resource 영역에 필요한 리소스들을 구비하고, 마이크로서비스가 어떤 양상으로 마이크로서비스 패턴을 사용하는가에 따라 common overlay를 재조합 하는 방식이 가능. 
* deploying overlay
  * TA/AA 영역
  * 앞선 microservice overlay를 모두 통합하여 최종 통합형상 생성
  * 공통 라벨, 어노테이션, 공통 이름 접미사/접두사를 선언