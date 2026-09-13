## 패키징 방법

- 기본적으로 아래와 같이 하면 패치 버전만 업데이트

bash tools/package.sh
# 1.0.0 → 1.0.1

- Minor 버전을 업데이트하고 싶으면 아래와 같이 하면 된다.

bash tools/package.sh --increase-minor-version
# 1.0.1 → 1.1.0