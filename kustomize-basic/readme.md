# 개요
06-gitbase의 컨텐츠를 직접 개발한다고 가정. 빈 프로젝트에서부터 기능개발, 배포를 위한 형상개발 및 연관 정보 애플리케이션 주입의 과정을 직접 수행한다.

# 실행

```
$ kustomize build  --load_restrictor none overlay/dev/v1 | kubectl apply -f -
namespace/quote-dev created
configmap/quote-app-config-dev-5c25k97bbh created
configmap/web-config-dev-9g62k48669 created
service/quote-app-service-dev created
service/redis-dev created
service/web-dev created
deployment.apps/quote-app-dev created
deployment.apps/redis-dev created
deployment.apps/web-dev created
```

```
$ kubectl port-forward svc/web-dev 31099:80   
Forwarding from 127.0.0.1:31099 -> 8080
Forwarding from [::1]:31099 -> 8080
Handling connection for 31099
Handling connection for 31099
```

```
$ curl http://localhost:31099/
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=600, initial-scale=1.0">
    <title>DEV-API</title>
</head>
<body>
    <h1>DEV Server Testing</h1>
    <p>The man who removes a mountain begins by carrying away small stones..</p>
</body>
</html>%                                 
```

```
$ kubectl port-forward svc/redis-dev 36379:6379
Forwarding from 127.0.0.1:36379 -> 6379
Forwarding from [::1]:36379 -> 6379
Handling connection for 36379
...
$ rdcli -p 36379
127.0.0.1:36379> keys *
1) qodCache::SimpleKey []
127.0.0.1:36379> get "qodCache::SimpleKey []"
��tEThe man who removes a mountain begins by carrying away small stones..
```

# 아키텍처

## Outer Architecture

Web(nodejs) - Quote(Spring Boot) - Redis(Backend) 로 구성됨.

### Web 서비스 특성
https://github.com/cloudsvcdev/render-api-html

백엔드 API를 호출하고 그 리턴값을 html 페이지에 출력하는 기능을 하는 서비스다. 

다음과 같이 두개의 환경변수를 받는다

| 이름 | 타입 | 기능 |
|---|---|---|
| API | string(url) | 렌더링 하고자 하는 API의 주소. 기본값 없음. |
| PAGE | string(ejs html) | API 결과값을 렌더링할 [EJS](https://ejs.co/) 포맷의 HTML 페이지. `<%= data %>` 에 API 결과값을 렌더링한다. 기본값은 단순한 HTML 페이지.

형상정보를 구성할 떄 API 에는 Quote 서비스의 Service 접근 주소를 제공한다. 

### Quote 서비스 특성
https://github.com/cloudsvcdev/quote-spring-app

http://quotes.rest/qod.json 를 호출하여 오늘의 인용구(Quote of the Day)를 가져오고 이를 돌려주는 API를 제공한다. 기본적으로 `/qod` 경로를 통해 API 값을 리턴한다.

```
$ kubectl port-forward svc/quote-app-service-dev 38080:38080
Forwarding from 127.0.0.1:38080 -> 8080
Forwarding from [::1]:38080 -> 8080
...
$ curl http://localhost:38080
{"timestamp":"2021-01-20T08:32:29.825+00:00","status":404,"error":"Not Found","message":"","path":"/"}%
$ curl http://localhost:38080/qod
The man who removes a mountain begins by carrying away small stones..%  
```

Quote앱이 주입받는 환경변수는 기본적으로 없다. 대신 `application.properties` 를 열어보게 되면 다음과 같은 로컬 개발 설정이 존재한다.

```properties
spring.cache.type=redis
spring.redis.port=6379
spring.redis.host=localhost
quote.api=http://quotes.rest/qod.json
```

이를 overlay에서는 다음과 같이 `application-dev.properties` 파일을 통해 정의값을 바꾸었다. `${REDIS_HOST}` 와 `${REDIS_PORT}` 는 spring properties에서 환경변수의 값을 대체하는 문법이다.

```properties
spring.cache.type=redis
spring.redis.port=${REDIS_PORT}
spring.redis.host=${REDIS_HOST}
quote.api=http://quotes.rest/qod.json
```

`quote-property-patch.yaml` 은 이 `application-dev.properties` 가 읽힐 수 있도록 `SPRING_PROFILES_ACTIVE` 값을 정의한다.

```yaml
        env:
        # /config/application-dev.properties 가 읽힐 수 있도록 환경변수 추가 주입
        - name: SPRING_PROFILES_ACTIVE
          value: dev
```

`quote-env-patch.yaml` 은 배포되는 REDIS의 실제 호스트 및 포트정보를 환경변수를 통해 주입한다. `$(REDIS_HOST)` 와 `$(REDIS_PORT)` 는 `kustomization.yaml`에 의해 선언된 변수값을 주입하는 kustomize의 문법이다.

```yaml
        env:
        # Spring boot 애플리케이션에서 환경변수로 바로 값을 주입하는게 아닌
        # application-dev.properties 를 통해 우회적으로 환경변수를 주입해야 하는 상황의 발생
        # 이와 같은 일이 없게 잘 설계할 수도 있으나, 문제 발생시에도 대응이 가능.
        - name: REDIS_HOST
          value: $(REDIS_HOST)
        - name: REDIS_PORT
          value: "$(REDIS_PORT)"
```

이 과정을 통해 `application-dev.properties` 에 명시된 `${REDIS_PORT}` 와 같은 값이 주입될 수 있게 된다.

## Inner Architecture

### Redis의 사용
인용구를 한번 호출해서 가져온 뒤엔 redis에 캐시처리한다. 이후 Quote API 호출시에는 redis 캐시로부터 값을 읽어서 즉시 리턴을 한다. 

```java
    @Cacheable(cacheNames = "qodCache")
    @GetMapping
    public String quote() {
        log.info("quote called");
        ResponseEntity<QuoteResponse> res = webClient
                .get()
                .retrieve()
                .toEntity(QuoteResponse.class)
                .block();
        String quote = res.getBody().contents.quotes[0].quote;
        log.info("retrieved quote is");
        log.info(quote);
        return quote;
    }
```

위와 같이 API 구현체에 `@Cacheable` 어노테이션을 추가하며, Spring Cloud Redis의 구현에 의해 Redis에 캐시값을 저장하게 된다. 실제 redis 에 접근해서 확인해보면 `qodCache::SimpleKey []` 라는 이름으로 캐시를 처리한 것을 확인할 수 있다.

```
$ kubectl port-forward svc/redis-dev 36379:6379
Forwarding from 127.0.0.1:36379 -> 6379
Forwarding from [::1]:36379 -> 6379
Handling connection for 36379
...
$ rdcli -p 36379
127.0.0.1:36379> keys *
1) qodCache::SimpleKey []
127.0.0.1:36379> get "qodCache::SimpleKey []"
��tEThe man who removes a mountain begins by carrying away small stones..
```

### Reactive Programming

Quote 앱의 `/qod/reactive` 경로에는 reactive/asynchronous 하게 개발된 API가 매핑되어 있다.

```java
    @GetMapping("/reactive")
    public Mono<String> quoteReactive() {
        return webClient.get()
                .retrieve()
                .bodyToMono(QuoteResponse.class)
//                .map(QuoteResponse::getFirstQuote);
                .map(quoteResponse -> {
                    String quote = quoteResponse.contents.quotes[0].quote;
                    log.info("[reactive] retrieved quote is"); //blocking?
                    log.info(quote);
                    return quote;
                });
```

위와 같이 API의 개발 방법이 기존의 절차적 프로그래밍과 다른 양상을 띄게 된다. 앞선 캐시 기반의 Rest API 의 구현에도 WebFlux를 사용한 reactive 코드의 일부분이 들어가 있으나, `.block()` 을 통해 결과값을 가져올 떄 까지 blocking 하도록 하여 일반적인 절차적 프로그래밍의 형태로 개발을 하도록 유도하고 있다.

TODO 설명작성

## 형상정보 작성에 있어서 Kustomize의 활용

### vars 를 이용한 리소스 이름 및 세부속성 추적

앞서 확인한 아키텍처를 보게 되면 Web앱은 Quote앱의 Service URL을 알아야 하며, Quote앱은 Redis Service의 URL을 알아야 한다. 이떄 서비스 URL값은 배포되는 Kubernetes Service 리소스의 `metadata.name` 값에 의해 결정되는데, 이 이름값을 환경변수에 주입하여 애플리케이션 간에 상호 호출을 한다. 

kustomize는 kubernetes에 맞게 형상정보를 생성하는 과정에서 리소스의 이름에 접미사나 접두사를 붙이거나 필요에 따라 hash값을 붙이는 등 최초에 명시된 이름과 최종 생성된 이름을 다르게 하는 기능이 제공된다. 샘플 서비스는 오버레이에서 `-dev` 접미사를 이름에 붙이는 수정을 가한다. 이와 같은 이름 및 리소스의 세부 속성/spec 변경을 인식할 수 있도록 하기 위해 `kustomization.yaml`에서는 `vars`라는 속성을 이용하여 리소스의 특정 속성을 변수화 할 수 있도록 기능을 제공한다.

Quote 서비스의 이름 변경이 어떻게 반영되는지 알아보자. `base/v1/kustomization.yaml`에는 다음과 같은 `vars` 선언이 들어가 있다.

```yaml
vars:
- name: QUOTE_APP_URL
  objref:
    apiVersion: v1
    kind: Service
    name: quote-app-service
  fieldref:
    fieldpath: metadata.name
- name: QUOTE_APP_PORT
  objref:
    apiVersion: v1
    kind: Service
    name: quote-app-service
  fieldref:
    fieldpath: spec.ports.0.port
```

`base/v1/quote.yaml` 에 선언되어 있는 `quote-app-service` Service에서 `metadata.name`과 첫번째 포트값을 읽어서 변수화 시키겠다는 선언이다. 이 변수는 웹 애플리케이션의 `API` 환경변수에 다음과 같은 형태로 주입된다. `base/v1/web.yaml`의  Deployment 선언에 다음과 같이 작성되어 있다. 

```yaml
        env:
        - name: API
          value: http://$(QUOTE_APP_URL):$(QUOTE_APP_PORT)/qod
```

달러 표시와 괄호를 이용해 변수를 대치하라고 선언하고 있으며, 실제 `kustomize build` 를 하게 되면 `overlay/dev/v1` 오버레이에 대해 다음과 같이 치환이 된다. 오버레이 에서는 `-dev` 접미사를 붙이도록 하고 있으며, 서비스의 포트를 8080에서 38080으로 변경하는 패치가 `quote-port-patch.yaml`에 반영되어 있고, 이러한 변경이 kustomize에 의해 자동으로 처리된다.

```yaml
        env:
        - name: API
          value: http://quote-app-service-dev:38080/qod
```

### 마이크로서비스를 위한 표준 폴더 구조

하나의 베이스를 가지고 모든 마이크로서비스에 확장하는 구조보다, 개별 마이크로서비스마다 1:n의 base:overlay 구조를 가지도록 구성한다. helm등을 활용할 때 하나의 chart를 가지고 상황에 맞는 values.yaml 을 사용하는것과 마찬가지 이유이다. 

* 각 마이크로서비스는 _deployment와 service 등을 가지고 있다_ 수준의 공통점 외에는 생명주기나 관리주체가 각기 상이하다. 프로젝트 상황에 따라 관리주체가 동일할 수는 있어도 생명주기는 다르다.
* 복수의 마이크로서비스에 대한 공통요소를 제공하기 위해 다음을 고려한다.
  * 형상정보는 하나의 git repository에 함께 보관한다
  * 마이크로서비스별로 폴더를 구분하여 형상정보를 관리한다. base-overlay는 마이크로서비스 별로 따로 구성이 된다.
  * 전체 공통요소(_예를들어 legacy나 DB에 대한 endpoint uri_)는 06-gitbase에서 설명했던것과 같이 공통패치 구조를 적용할 수 있도록 최초 형상정보 작성시 고려한다.
* 공통패치를 위한 고려사항은 다음과 같다.
  * 전체 공통요소가 반영될 수 있도록 마이크로서비스들은 동일한 `metadata.name`을 가지도록 할 수 있다.
    * 마이크로서비스들은 `nameSuffix`와 `namePrefix`를 이용하여 자기 자신 및 배포 환경에 대한 구분을 수행한다.
    * 동일한 `metadata.name` 을 가짐으로써 base-overlay 폴더 외에 위치한 공통패치를 참조만 함으로써 바로 설정정보가 바뀔 수 있다.
    * `kustomization.yaml`의 `patchesStrategicMerge` 속성이 이 방식에 사용될 수 있다.
  * 마이크로서비스들은 동일한 `metadata.name`을 가지지 않아도 공통패치를 적용받을 수 있다.
    * `kustomization.yaml`의 `patches`에 JSON Patch를 명시하면서 패치 대상 리소스를 명시적으로 작성할 수 있다. 
    * 설정 정보를 주입하는 JSON Patch는 수정 행위는 명시하지만 수정 대상은 명시하지 않는다. 패치 대상을 패치 내에 명시하는 `patchesStrategicMerge` 와 달리 JSON patch 적용시에는 `kustomization.yaml`에 어떤 리소스가 패치를 받을지를 명시하게 된다.
  * 파일럿 형상정보의 복잡성을 보고, 마이크로서비스들이 base에서 동일한 `metadata.name`을 가지고 형상을 꾸밀 수 있다면 `patchesStrategicMerge`를 사용, 그렇지 않다면 약간은 수정사항이 늘더라도 `patches`를 통해 JSON patch를 사용하는 식으로 응용하게 된다.

## 빌드배포 아키텍처 

TBA