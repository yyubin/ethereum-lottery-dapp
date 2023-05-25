# 이더리움을 활용한 Lottery Dapp

### Reference

https://www.inflearn.com/course/ethereum-dapp

- - -

# Dapp 서비스 설계

### 지갑관리

### 아키텍처
1. smart contract - front
2. smart contract - server - front

### code
1. 코드를 실행할때에도 돈이 든다
2. 권한 관리
3. 비지니스 로직 업데이트
4. 데이터 마이그레이션

### 운영
1. public
2. private


- - -


# Lottery 규칙

1. + 3 번째 블록해시의 첫 두 글자 맞추기
    * 유저가 던진 트랜잭션이 들어가는 블록 + 3 의 블록해쉬와 값 비교
2. Pot money
    * 결과가 나왔을 때만 유저가 보낸 돈을 팟머니에 쌓음
    * 여러 명이 맞추었을 경우 가장 먼저 맞춘 사람이 팟머니를 가져감
    * 두 글자 중 하나만 맞추었을 경우 보낸 돈을 돌려줌
    * 결과 값을 검증할 수 없을 경우 보낸 돈을 돌려줌