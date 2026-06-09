# 3DBall 프로젝트 가이드 — 플랫폼을 기울여 공 끝까지 유지하기

## 1. 개요

3DBall은 ML-Agents의 가장 대표적인 예제 환경입니다.
에이전트(플랫폼) 위에 공이 떠 있고, 플랫폼을 기울여 공이 떨어지지 않도록
유지하는 것이 목표입니다. 3가지 변형(기본, 하드, 비주얼)이 있으며,
이 가이드에서는 **Mean Reward 100 달성**을 목표로 프로젝트를 완성하는
전 과정을 다룹니다.

### 학습 환경 구조

```
     [Ball]         ← 공이 플랫폼 위에 있음
    ──────
   [Platform]      ← Agent가 제어하는 플랫폼 (Z축 / X축 회전)
   (Rotation ±14°)
```

---

## 2. 문제 정의 (Problem Definition)

### 2.1 "공을 끝까지 유지한다"는 것의 의미

| 용어 | 실제 의미 |
|------|-----------|
| **하나의 에피소드** | 공이 플랫폼 위에서 떨어질 때까지의 1회 시도 |
| **스텝(Step)** | 물리 시뮬레이션 1프레임 (0.02초, 즉 50FPS) |
| **에피소드 길이** | 공이 떨어질 때까지의 스텝 수 |
| **Reward (한 스텝)** | +0.1 (생존) 또는 -1 (실패, 에피소드 종료) |
| **Mean Reward 100** | 최근 100개 에피소드의 평균 보상이 100 |

### 2.2 Mean Reward 100을 스텝 수로 환산

```
Mean Reward 100 = 평균적으로 1000스텝 동안 공을 유지
                = 약 20초 (1000스텝 × 0.02초)
```

즉, Mean Reward 100 달성 = **평균 20초 이상 공을 플랫폼 위에서 유지**한 상태입니다.

### 2.3 성공 기준 설정

```
실패 조건 (공이 떨어짐):
  - ball.position.y - platform.position.y < -2m  (아래로 이탈)
  - |ball.position.x - platform.position.x| > 3m (좌우로 이탈)
  - |ball.position.z - platform.position.z| > 3m (앞뒤로 이탈)

성공 = 위 조건에 한 번도 걸리지 않고 1000스텝(20초) 생존
```

### 2.4 프로젝트 완성 로드맵

```
Phase 1: 환경 이해와 설정
  → 3DBall씬 구조 파악, Ball3DAgent 코드 분석,
    커맨드라인으로 ml-agents-learn 실행 확인

Phase 2: 첫 번째 학습 실행
  → 기본 하이퍼파라미터로 학습, TensorBoard로 결과 모니터링,
    Mean Reward 100 달성 확인

Phase 3: 하이퍼파라미터 튜닝
  → learning rate, batch size, gamma 등을 변경하며
    학습 속도와 안정성 개선

Phase 4: 보상 설계 실험
  → 지속 보상 크기, 패널티 강도, 거리 기반 보상 등을
    변경하여 에이전트 행동 변화 관찰

Phase 5: Curriculum Learning
  → 공의 크기/질량을 점진적으로 변경하여
    더 강인한 에이전트로 발전

Phase 6: 모델 평가 & 배포
  → 학습된 .onnx 모델을 Unity에서 Inference로 실행,
    실제 성능 검증 및 튜닝
```

---

## 3. 프로젝트 설정하기

### 3.1 학습 명령어

```bash
mlagents-learn config/ppo/3DBall.yaml --run-id=3DBall_Project
```

### 3.2 TensorBoard로 모니터링 (별도 터미널)

```bash
tensorboard --logdir results --port 6006
# 브라우저에서 http://localhost:6006 열기
```

### 3.3 학습 중단 후 재개

```bash
mlagents-learn config/ppo/3DBall.yaml --run-id=3DBall_Project --resume
```

### 3.4 학습된 모델로 Unity에서 테스트

```bash
mlagents-learn config/ppo/3DBall.yaml --run-id=3DBall_Project --play
```

---

## 4. 입력 설계: 관찰(Observation)과 액션(Action)

### 4.1 관찰 설계 이유

| 관찰 | 타입 | 왜 이 값을 사용하는가 |
|------|------|----------------------|
| 플랫폼 Z축 회전 (0) | float | "지금 플랫폼이 얼마나 기울었는가" — 공이 굴러가는 방향 결정 |
| 플랫폼 X축 회전 (1) | float | 위와 동일, 직교 축 |
| 공의 상대 위치 (2~4) | Vector3 | "공이 플랫폼의 어디에 있는가" — 중심에서 멀수록 위험 |
| 공의 선속도 (5~7) | Vector3 | "공이 어느 방향으로 얼마나 빠르게 움직이는가" — 미래 위치 예측 |

**이 데이터만으로 왜 충분한가?**
- 공의 위치 + 속도를 알면 다음 스텝의 공 위치를 예측 가능
- 플랫폼 기울기를 알면 현재 제어 상태를 파악 가능
- 8차원으로 최소한의 정보로 문제를 해결하도록 설계됨

### 4.2 액션 설계 이유

```csharp
var actionZ = 2f * Mathf.Clamp(continuousActions[0], -1f, 1f);  // → [-2, 2]
var actionX = 2f * Mathf.Clamp(continuousActions[1], -1f, 1f);  // → [-2, 2]
```

- 연속 액션 2개: Z축 회전(좌우) + X축 회전(앞뒤)
- 액션값 [-1, 1]을 [-2, 2]로 스케일링 → 더 민감한 제어 가능
- **회전 제한 ±0.25 라디안**(약 ±14도): 너무 급격한 기울기 방지

**왜 Discrete가 아니라 Continuous인가?**
- 공의 위치는 연속적인 값 → 이산적인 On/Off 제어로는 정밀한 균형 불가능
- 마치 인체가 넘어지지 않도록 지속적으로 미세 조정하는 것과 동일

### 4.3 하이퍼파라미터 선택 가이드

| 파라미터 | 3DBall 기본값 | 변경해볼 값 | 효과 |
|----------|--------------|------------|------|
| `batch_size` | 64 | 128, 256 | 클수록 안정적이지만 느림 |
| `buffer_size` | 2048 | 4096 | 클수록 다양한 경험 수집 |
| `learning_rate` | 3.0e-4 | 1.0e-3, 1.0e-4 | 높으면 빠르지만 불안정 |
| `gamma` | 0.99 | 0.95, 0.995 | 높을수록 장기 보상 중요시 |
| `hidden_units` | 128 | 256, 64 | 클수록 복잡한 패턴 학습 |
| `max_steps` | 500000 | 1000000 | 더 오래 학습시키면 더 단단해짐 |

### 4.4 환경 파라미터 (Curriculum Learning)

```csharp
m_BallRb.mass = m_ResetParams.GetWithDefault("mass", 1.0f);
var scale = m_ResetParams.GetWithDefault("scale", 1.0f);
```

훈련 구성 파일에서 이렇게 설정하면 공의 물성을 변경할 수 있습니다:

```yaml
# 3DBall.yaml 의 environment_parameters 섹션
environment_parameters:
  mass:
    curriculum:
      - name: "Lesson1"
        completion_criteria:
          measure: reward
          behavior: 3DBall
          min_lesson_length: 100
          threshold: 80
          require_reset: true
        value: 1.0
      - name: "Lesson2"
        completion_criteria:
          measure: reward
          behavior: 3DBall
          min_lesson_length: 100
          threshold: 90
          require_reset: true
        value: 0.5
      - name: "Lesson3"
        completion_criteria:
          measure: reward
          behavior: 3DBall
          min_lesson_length: 100
          threshold: 95
          require_reset: true
        value: 0.25
```

---

## 5. 보상 설계 (Reward Design)

### 5.1 기본 보상 구조

| 상황 | 보상 | 의도 |
|------|------|------|
| 공이 플랫폼 위에 있음 | **+0.1** (매 스텝) | 생존 자체에 보상 → 더 오래 유지하도록 유도 |
| 공이 떨어짐 | **-1** (1회) + 에피소드 종료 | 실패 페널티, 동시에 에피소드 종료로 재시도 |

### 5.2 보상의 수학적 의미

```
하나의 에피소드에서:
  총 보상 = (생존 스텝 수) × 0.1 - (떨어진 횟수) × 1

1000스텝 생존 시:
  총 보상 = 1000 × 0.1 = 100

Mean Reward 100 = 평균 1000스텝 생존 = 약 20초 유지
```

### 5.3 보상 설계의 트레이드오프

| 설계 | 장점 | 단점 |
|------|------|------|
| +0.1 생존 보상만 | 학습初期에 생존 행동 빠르게 습득 | 위험을 감수하지 않음 |
| +0.01 생존 보상 (↓) | 더 완벽한 정책 요구 | 학습이 느려짐 |
| +1 생존 보상 (↑) | 빨리 배우지만 불안정 | Overshoot 발생 가능 |
| -5 실패 (↓) | 실패를 강하게 회피 | 위험 회피만 하고 탐험 안 함 |

### 5.4 대체 보상 설계 실험

**실험 A: 거리 기반 보상**
```csharp
// 공이 중심에 가까울수록 높은 보상
var distanceFromCenter = Vector3.Distance(
    ball.transform.position, gameObject.transform.position);
var reward = Mathf.Max(0, 1.0f - distanceFromCenter / 3.0f);
AddReward(reward);
```

**실험 B: 속도 기반 보상**
```csharp
// 공의 속도가 느릴수록 높은 보상 (안정적 균형 유도)
var speed = m_BallRb.linearVelocity.magnitude;
var reward = Mathf.Max(0, 1.0f - speed / 5.0f);
AddReward(reward);
```

**실험 C: 하이브리드**
```csharp
var distanceReward = 1.0f - distanceFromCenter / 3.0f;
var speedReward = 1.0f - speed / 5.0f;
AddReward(0.7f * distanceReward + 0.3f * speedReward);
```

---

## 6. 학습 과정과 결과 해석

### 6.1 TensorBoard 핵심 메트릭

| 메트릭 이름 | 의미 | 좋은 신호 |
|------------|------|-----------|
| `Environment/Mean Reward` | 최근 100개 에피소드 평균 보상 | 100에 수렴 = 성공 |
| `Policy/Learning Rate` | 학습률 감소 추이 | Linear decay 확인 |
| `Policy/Entropy` | 정책의 무작위성 | 점진적 감소 = 확실한 정책 형성 |
| `Policy/Value Estimate` | 가치 함수 추정값 | 보상과 비슷한 수준으로 수렴 |
| `Policy/Value Loss` | 가치 함수 학습 손실 | 안정적으로 감소 |
| `Policy/Policy Loss` | 정책 학습 손실 | 작은 값 유지 |

### 6.2 학습 과정 상세

```
Step       Mean Reward    관찰
─────────────────────────────────────────────────────
0            0.000       에이전트가 완전히 랜덤하게 행동
12,000       ~10         공이 떨어지지 않도록 하는 법을 배우기 시작
30,000       ~25         어느 정도 균형을 맞출 수 있게 됨
60,000       ~40-60      상당히 안정적으로 공을 유지
90,000       ~80         거의 떨어뜨리지 않음
120,000      100.000     ★ 목표 달성! 평균 1000스텝(20초) 생존
200,000      100.000     안정적인 정책 유지
500,000      100.000     학습 종료, 모델 저장
```

### 6.3 학습 실패 시나리오와 대처

| 증상 | 원인 | 해결책 |
|------|------|--------|
| Mean Reward가 0 근처에 머묾 | 학습률이 너무 낮거나 네트워크가 너무 작음 | `learning_rate` 증가, `hidden_units` 증가 |
| Mean Reward가 진동함 | `batch_size`가 너무 작음 | `batch_size` 64 → 128 |
| 학습은 되지만 100에 도달 못 함 | `max_steps` 부족 | `max_steps` 500000 → 1000000 |
| 공이 한쪽으로만 계속 굴러감 | 보상 설계 문제 | 거리 기반 보상 추가 고려 |
| Entropy가 0에 수렴 (Early) | 탐험 조기 종료 | `beta` (entropy bonus) 증가 |

---

## 7. Ball3DHardAgent — 더 어려운 도전

### 7.1 기본 버전과의 차이

| 항목 | Ball3DAgent | Ball3DHardAgent |
|------|-------------|-----------------|
| 관찰 방식 | 직접 VectorSensor 작성 | `[Observable]` 애트리뷰트 자동 생성 |
| 관찰 내용 | 회전 + 위치 + 속도 (8차원) | 회전 + 위치 (5차원, 9스택) |
| 관찰 차원 | 8 | 5 × 9 = 45 (9스텍) |
| 학습 난이도 | 낮음 | 높음 (과거 정보를 스스로 조합해야 함) |

```csharp
// Ball3DHardAgent의 관찰
[Observable(numStackedObservations: 9)]
Vector2 Rotation { get; }              // Z축 + X축 회전 (2차원)

[Observable(numStackedObservations: 9)]
Vector3 PositionDelta { get; }         // 공의 상대 위치 (3차원)
```

- **9스택**: 현재 + 과거 8스텝의 정보를 누적
- 속도 정보가 없음 → 위치 변화를 9스택으로 추론해야 함
- 더 풍부한 시퀀스 정보로 더 정확한 제어 가능

### 7.2 Ball3DHardAgent 학습 결과

```
Step 180000: Mean Reward 100 달성 (기본보다 약 50% 더 느림)
Step 500000: Mean Reward 100 유지
```

---

## 8. Visual3DBall — 시각 관찰 학습

### 8.1 설정 방법

- `useVecObs = false`로 설정
- 벡터 관찰이 비활성화되고, 카메라 화면을 CNN으로 처리
- 관찰 = 카메라 픽셀 데이터 (84×84×3 RGB)

### 8.2 예상 결과

벡터 관찰보다 훨씬 많은 학습 스텝이 필요하고, 컴퓨터 사양에 따라
학습 시간이 5~10배 더 오래 걸립니다.

---

## 9. 실전 프로젝트 — 단계별 가이드

### Phase 1: 환경 검증 (5분)

```bash
# 1. Python 환경 확인
pip show mlagents

# 2. Unity 빌드 확인 (3DBall 씬이 Build Settings에 포함되어 있는지)

# 3. ml-agents-learn 정상 작동 확인
mlagents-learn --help

# 4. Heuristic 모드로 사람이 직접 플레이
# Unity 에디터에서 3DBall 실행 → W/A/S/D 키로 공 유지해보기
```

### Phase 2: 첫 학습 (15분)

```bash
mlagents-learn config/ppo/3DBall.yaml --run-id=3DBall_First
```

- TensorBoard 열어서 Mean Reward 변화 관찰
- Step 120000 근처에서 Mean Reward 100 달성하는지 확인
- 달성 안 되면 `max_steps`를 늘려서 재실행

### Phase 3: 하이퍼파라미터 튜닝 (30분)

같은 설정으로 3번 실행해서 편차를 확인합니다:

```bash
mlagents-learn config/ppo/3DBall.yaml --run-id=3DBall_Tune1 --seed=1
mlagents-learn config/ppo/3DBall.yaml --run-id=3DBall_Tune2 --seed=42
mlagents-learn config/ppo/3DBall.yaml --run-id=3DBall_Tune3 --seed=123
```

각 실행의 Mean Reward 곡선을 TensorBoard에서 비교합니다.

### Phase 4: 보상 변경 실험 (30분)

위 "5.4 대체 보상 설계 실험"의 A/B/C를 각각 학습시켜 비교합니다.

### Phase 5: Ball3DHardAgent 도전 (30분)

```bash
mlagents-learn config/ppo/3DBall.yaml --run-id=3DBall_Hard --env-args="--hard"
```

### Phase 6: 모델 배포

```bash
# 학습 완료 후 .onnx 파일을 Unity 프로젝트로 복사
cp results/3DBall_First/3DBall.onnx UnityProject/Assets/ML-Agents/Models/
```

Unity에서 `Behavior Parameters`의 `Model`에 해당 onnx 파일을 지정하고
`Inference Device`를 `CPU` 또는 `GPU`로 설정한 후 실행합니다.

---

## 10. 실습 과제

### 과제 1: 기본 학습 → Mean Reward 100 달성
- 기본 설정 그대로 학습 실행
- TensorBoard에서 Mean Reward 100 달성 시점과 Step 수 기록
- **예상**: 약 Step 120000에서 달성

### 과제 2: 지속 보상 변경 실험
- 생존 보상을 +0.1 → +0.05, +0.2로 각각 변경
- 보상 크기에 따른 학습 속도 차이 비교
- **질문**: 보상이 너무 크면 왜 불안정해질까?

### 과제 3: Balth3DHardAgent와 비교
- Ball3DAgent와 Ball3DHardAgent를 같은 max_steps로 학습
- 관찰 방식의 차이가 학습 속도와 최종 성능에 미치는 영향 분석
- **핵심**: 9스택 관찰이 1스텝 관찰보다 더 좋은가?

### 과제 4: Curriculum Learning
- 공의 크기를 1.0 → 0.75 → 0.5로 줄여가며 학습
- 각 단계에서 Mean Reward 100 달성 후 다음 단계로 진행
- **결과**: 더 작은 공으로도 균형을 유지하는 강인한 정책

### 과제 5: Reward 설계 경진
- A: 생존 보상 +0.1 (기본)
- B: 거리 기반 (중심에 가까울수록 높은 보상)
- C: 속도 기반 (느릴수록 높은 보상)
- D: 앙상블 (거리 × 0.7 + 속도 × 0.3)

각각 학습시켜서 가장 빠르게 Mean Reward 100에 도달하는 설계를 찾아보세요.

---

## 11. 파일 구조

```
3DBall/
├── Scenes/
│   ├── 3DBall.unity              # 기본 (벡터 관찰)
│   ├── 3DBallHard.unity          # 하드 (Reflection Sensor)
│   └── Visual3DBall.unity        # 비주얼 (카메라 관찰)
├── Scripts/
│   ├── Ball3DAgent.cs            # 기본 에이전트
│   └── Ball3DHardAgent.cs        # 하드 에이전트
├── Prefabs/
│   ├── 3DBall.prefab
│   ├── 3DBallHard.prefab
│   └── Visual3DBall.prefab
├── TFModels/
│   ├── 3DBall.onnx
│   ├── 3DBallHard.onnx
│   └── Visual3DBall.onnx
└── Demos/
    ├── Expert3DBall.demo
    └── Expert3DBallHard.demo
```

---

## 12. 핵심 포인트

- **Mean Reward 100** = 1000스텝(약 20초) 생존 = 프로젝트 완성 기준
- 8차원 관찰 (회전 + 위치 + 속도)로 최소한의 정보로 문제 해결
- 2차원 연속 액션 (Z축 + X축)으로 ±14도 범위 내에서 미세 제어
- 생존 보상(+0.1) + 실패 패널티(-1) 구조로 지속적 균형 행동 학습
- 약 12만 스텝(4분)이면 Mean Reward 100 달성 가능
- TensorBoard 메트릭(Mean Reward, Entropy, Value Estimate)을 통한 학습 진단
- Curriculum Learning으로 공의 물성을 변경하며 강인한 정책 개발
- Ball3DHardAgent는 9스택 Reflection Sensor로 더 풍부한 시퀀스 정보 활용
