# 3DBall 예제 가이드

## 1. 개요

3DBall은 ML-Agents의 가장 대표적인 예제 환경입니다.
에이전트(플랫폼) 위에 공이 떠 있고, 플랫폼을 기울여 공이 떨어지지 않도록 유지하는 것이 목표입니다.
3가지 변형(기본, 하드, 비주얼)이 있으며, 3DBall은 실제 학습이 검증된 환경입니다.

**목표**: 플랫폼을 기울여 공을 끝까지 유지 (Mean Reward 100 달성 가능)

### 학습 환경 구조

```
     [공]          ← 공이 플랫폼 위에 있음
    ──────
   [Platform]      ← Agent가 제어하는 플랫폼
   (회전 가능)
```

---

## 2. 코드 분석

### 2.1 Ball3DAgent.cs

`Agent` 클래스를 상속받는 표준 에이전트입니다.

```csharp
public class Ball3DAgent : Agent
{
    [Header("Specific to Ball3D")]
    public GameObject ball;
    public bool useVecObs;      // 벡터 관찰 사용 여부
    Rigidbody m_BallRb;
    EnvironmentParameters m_ResetParams;
}
```

#### Initialize() - 초기화
```csharp
public override void Initialize()
{
    m_BallRb = ball.GetComponent<Rigidbody>();
    m_ResetParams = Academy.Instance.EnvironmentParameters;
    SetResetParameters();
}
```

#### CollectObservations() - 관찰 수집
```csharp
public override void CollectObservations(VectorSensor sensor)
{
    if (useVecObs)
    {
        sensor.AddObservation(gameObject.transform.rotation.z);          // Z축 회전
        sensor.AddObservation(gameObject.transform.rotation.x);          // X축 회전
        sensor.AddObservation(ball.transform.position - gameObject.transform.position);  // 공의 상대 위치 (Vector3)
        sensor.AddObservation(m_BallRb.linearVelocity);                  // 공의 속도 (Vector3)
    }
}
```

**관찰 공간**: 8차원 벡터 (useVecObs=true)
| 인덱스 | 내용 |
|--------|------|
| 0 | 플랫폼 Z축 회전 |
| 1 | 플랫폼 X축 회전 |
| 2-4 | 공의 상대 위치 (x, y, z) |
| 5-7 | 공의 선속도 (vx, vy, vz) |

`useVecObs=false`이면 관찰 없음 → Visual Observation만 사용 (Visual3DBall)

#### OnActionReceived() - 액션 처리
```csharp
public override void OnActionReceived(ActionBuffers actionBuffers)
{
    var actionZ = 2f * Mathf.Clamp(actionBuffers.ContinuousActions[0], -1f, 1f);
    var actionX = 2f * Mathf.Clamp(actionBuffers.ContinuousActions[1], -1f, 1f);

    // Z축 회전 (좌우 기울기)
    if ((gameObject.transform.rotation.z < 0.25f && actionZ > 0f) ||
        (gameObject.transform.rotation.z > -0.25f && actionZ < 0f))
    {
        gameObject.transform.Rotate(new Vector3(0, 0, 1), actionZ);
    }

    // X축 회전 (앞뒤 기울기)
    if ((gameObject.transform.rotation.x < 0.25f && actionX > 0f) ||
        (gameObject.transform.rotation.x > -0.25f && actionX < 0f))
    {
        gameObject.transform.Rotate(new Vector3(1, 0, 0), actionX);
    }

    // 공이 떨어졌는지 확인 (보상 및 종료)
    if ((ball.transform.position.y - gameObject.transform.position.y) < -2f ||
        Mathf.Abs(ball.transform.position.x - gameObject.transform.position.x) > 3f ||
        Mathf.Abs(ball.transform.position.z - gameObject.transform.position.z) > 3f)
    {
        SetReward(-1f);
        EndEpisode();
    }
    else
    {
        SetReward(0.1f);  // 공이 플랫폼 위에 있으면 지속 보상
    }
}
```

**액션 공간**: 2차원 연속(Continuous) 액션
| 액션 | 범위 | 효과 |
|------|------|------|
| actionZ | [-1, 1] | Z축 회전 (좌우 기울기) |
| actionX | [-1, 1] | X축 회전 (앞뒤 기울기) |

**회전 제한**: ±0.25 라디안(약 ±14도) 이내로 제한

#### OnEpisodeBegin() - 에피소드 시작
```csharp
public override void OnEpisodeBegin()
{
    gameObject.transform.rotation = new Quaternion(0f, 0f, 0f, 0f);
    gameObject.transform.Rotate(new Vector3(1, 0, 0), Random.Range(-10f, 10f));
    gameObject.transform.Rotate(new Vector3(0, 0, 1), Random.Range(-10f, 10f));
    m_BallRb.linearVelocity = new Vector3(0f, 0f, 0f);
    ball.transform.position = new Vector3(Random.Range(-1.5f, 1.5f), 4f, Random.Range(-1.5f, 1.5f))
        + gameObject.transform.position;
    SetResetParameters();
}
```
- 플랫폼 초기 회전 랜덤화 (-10° ~ 10°)
- 공의 초기 위치 랜덤화 (±1.5 범위)

#### Heuristic() - 수동 조작
```csharp
public override void Heuristic(in ActionBuffers actionsOut)
{
    var continuousActionsOut = actionsOut.ContinuousActions;
    continuousActionsOut[0] = -Input.GetAxis("Horizontal");  // A/D 또는 ←/→
    continuousActionsOut[1] = Input.GetAxis("Vertical");      // W/S 또는 ↑/↓
}
```

#### SetBall() - Curriculum Learning 지원
```csharp
public void SetBall()
{
    m_BallRb.mass = m_ResetParams.GetWithDefault("mass", 1.0f);
    var scale = m_ResetParams.GetWithDefault("scale", 1.0f);
    ball.transform.localScale = new Vector3(scale, scale, scale);
}
```
- 공의 질량과 크기를 환경 파라미터로 조절 가능
- Curriculum Learning에서 공을 점점 작게/가볍게 만들어 난이도 조절

### 2.2 Ball3DHardAgent.cs (3DBallHard)

`Ball3DAgent`와 유사하지만 **Reflection Sensor**를 사용합니다.

```csharp
public class Ball3DHardAgent : Agent
{
    [Observable(numStackedObservations: 9)]
    Vector2 Rotation
    {
        get {
            return new Vector2(gameObject.transform.rotation.z, gameObject.transform.rotation.x);
        }
    }

    [Observable(numStackedObservations: 9)]
    Vector3 PositionDelta
    {
        get {
            return ball.transform.position - gameObject.transform.position;
        }
    }
}
```

- `[Observable]` 애트리뷰트로 관찰 자동 생성
- `numStackedObservations: 9` → 9스텝의 과거 관찰을 스택하여 사용
- Ball3DAgent와 동일한 액션 공간과 보상 구조
- 벡터 관찰 없음 (관찰은 `Rotation` + `PositionDelta`만)

---

## 3. 관찰-액션-보상 구조

| 항목 | Ball3DAgent | Ball3DHardAgent | Visual3DBall |
|------|-------------|-----------------|--------------|
| **관찰** | 8차원 벡터 | Reflection Sensor (2+3차원, 9스택) | Visual (카메라) |
| **액션** | 연속 2개 | 연속 2개 | 연속 2개 |
| **보상** | 스텝당 +0.1, 실패 -1 | 스텝당 +0.1, 실패 -1 | 스텝당 +0.1, 실패 -1 |

---

## 4. 학습 실행

### 4.1 학습 설정 (config/ppo/3DBall.yaml)

```yaml
behaviors:
  3DBall:
    trainer_type: ppo
    hyperparameters:
      batch_size: 64
      buffer_size: 2048
      learning_rate: 3.0e-4
      beta: 5.0e-4
      epsilon: 0.2
      lambd: 0.99
      num_epoch: 3
      learning_rate_schedule: linear
    network_settings:
      normalize: false
      hidden_units: 128
      num_layers: 2
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    max_steps: 500000
    time_horizon: 64
    summary_freq: 30000
    keep_checkpoints: 5
```

### 4.2 학습 명령어

```bash
mlagents-learn config/ppo/3DBall.yaml --run-id=3DBall_Test
```

### 4.3 학습 결과 (실제 검증됨)

3DBall 학습은 실제 성공이 검증된 환경입니다.

```
Step 12000: Mean Reward 약 10 (초기 학습 시작)
Step 60000: Mean Reward 약 40-60
Step 120000: Mean Reward 100.000 달성 (약 4분)
...
Step 500267: Mean Reward 100.000 유지, 모델 저장
```

**총 소요 시간**: 약 15분 (500K 스텝)
**최종 결과**: Mean Reward 100.000

---

## 5. 실습 과제

### 과제 1: 난이도 변경
- Ball3DHardAgent를 사용하여 학습해보고 기본 버전과 성능을 비교하세요.
- Ball3DAgent와 Ball3DHardAgent의 관찰 차이가 학습에 미치는 영향을 분석하세요.

### 과제 2: 보상 구조 변경
- 지속 보상을 +0.1 대신 +0.05로 낮추면 학습이 어떻게 달라지는지 확인하세요.
- 공이 떨어졌을 때의 패널티를 -1 대신 -5로 변경해보세요.

### 과제 3: Curriculum Learning
- 공의 크기를 점점 작게 만들어 난이도를 높이는 Curriculum을 구성하세요.
- `SetBall()`에서 `scale` 파라미터를 단계별로 1.0 → 0.8 → 0.6으로 줄이기.

### 과제 4: 회전 제한 변경
- 현재 ±0.25 라디안인 회전 제한을 ±0.5로 늘려보세요.
- 너무 큰 회전 제한이 학습에 미치는 영향을 관찰하세요.

### 과제 5: Visual Observation 학습
- `Visual3DBall` 씬에서 `useVecObs=false`로 설정하고 학습해보세요.
- 벡터 관찰만 사용한 경우와 시각 관찰만 사용한 경우의 학습 속도 차이를 비교하세요.

---

## 6. 파일 구조

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

## 7. 핵심 포인트

- 연속적 제어(Continuous Control)의 가장 기본적인 예제
- 실패 조건 감지 및 지속 보상의 결합
- `useVecObs`를 통한 Vector/Visual Observation 전환
- `Heuristic()`을 통한 사람의 수동 조작 및 데모 기록
- `EnvironmentParameters`를 통한 Curriculum Learning 지원
- 회전에 물리 제약을 두어 현실적인 제어 학습
- Ball3DAgent(기본)와 Ball3DHardAgent(Reflection)의 관찰 방식 차이
