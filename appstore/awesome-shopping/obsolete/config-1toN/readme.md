# 기존 형상 단순화
기존에 단일 deployment를 이용해 마이크로서비스별 overlay로 세분화 하는 예시를 좀 더 단순화
base에는 단일 deployment위치
각 오버레이는 이를 가져와서 세분화
`overlay/v1/dev/z_all`은 전체를 모두 재참조.

# kustomize 빌드 방법

kustomize cli 3.9.1 에서 테스트됨. 

다음은 전체를 빌드하는 명령. 공통패치 구현을 위해 `--load_restrictor none` 옵션 사용. 3.9.x 에서의 버그([패치에서 한글처리가 안됨](https://github.com/kubernetes-sigs/kustomize/issues/3417))를 해소하기 위해 `--enable_kyaml=false` 옵션도 필요. 
```
kustomize build --load_restrictor none --enable_kyaml=false overlay/v1/dev/z_all
```

다음은 개별 마이크로서비스를 빌드하는 명령.
```
kustomize build --load_restrictor none --enable_kyaml=false overlay/v1/dev/account
```

# 폴더 구성의 가정사항
awesome-shopping 애플리케이션 소스코드들은 

# 공통패치의 가정사항
`common/backend/dev/backend-cred-patch.yaml` 은 배포되는 환경에 다음의 시크릿이 존재함을 가정한다. 따라서 상황에 맞게 시크릿을 미리 배포해야 한다. 이는 소스코드 상에 인증정보가 포함되지 않게 하기 위함이다. 이 패치는 오버레이의 `patchesStrategicMerge` 에서 사용한다.

| secret name | 포함 키 |
| -- | -- |
| redis-secret | password |
| mariadb-secret | user, password |
| rabbitmq-secret | user, password |

`common/backend/dev/application.yaml` 은 위 시크릿이 존재한다고 가정할 때 각종 마이크로서비스 패턴을 사용하기 위해 필요한 설정정보를 포함하는 영역이다. 오버레이의 `configMapGenerator`에서 이 파일을 참조한다.

위의 두개 파일은 오버레이에서 함께 참조되어야 하는 성격으로 작성되어 있다.

## base 외부화(github등을 url형태로 참조)시 고려사항
patch는 kustomize 개념상 overlay의 소속 속성으로, overlay에서 값을 바꾸는데 쓰이는 도구로 쓰인다. 이러한 이유로 kustomize에서는 기본적으로 overlay의 하위 폴더에 패치 파일들을 두는것을 가정하며 이 patch들은 git url로 참조할 수가 없다. 

형상정보를 git 등으로 외부화 하는 과정에서 base와 overlay 조차도 별도의 git repository로 구성하게 될 경우 common patch 영역은 반드시 overlay와 함께 두어야 한다. 만일 접근권한을 제어하기 위해 common patch 를 개발자가 아예 수정하지 못하도록 base 영역으로 옮기고자 할 경우엔 base+common 을 별도 폴더로 구성하기 보다는 base 자체에 공통패치에 해당되는 사항을 작성하여 구성하는것이 맞다. 