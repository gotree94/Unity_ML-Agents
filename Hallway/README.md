# Hallway 예제 가이드

## 1. 개요

Hallway는 에이전트가 복도 끝까지 이동하여 두 개의 목표(O와 X) 중 올바른 것을 선택하는 환경입니다.
에피소드 시작 시 O 또는 X 심볼 중 하나가 표시되고, 에이전트는 해당 심볼이 있는 목표 지점으로
이동해야 합니다. 목표 위치도 랜덤하게 좌우로 변경됩니다.

**목표**: 표시된 심볼과 일치하는 목표 지점에 도달하기

### 학습 환경 구조

```
[시작 지점] →→→→→→→→→ [복도] →→→→→→→→→ [O] [X] (두 목표 중 선택)
                      ↑                   ↑
                  (심볼 표시)        (목표 위치 랜덤)
```

---

## 2. 코드 분석

### 2.1 HallwayAgent.cs

복도를 따라 이동하며 올바른 목표를 선택하는 에이전트입니다.

```csharp
public class HallwayAgent : Agent
{
    public GameObject ground;
    public GameObject area;
    public GameObject symbolOGoal;    // O 목표 지점
    public GameObject symbolXGoal;    // X 목표 지점
    public GameObject symbolO;        // 표시된 O 심볼
    public GameObject symbolX;        // 표시된 X 심볼
    public bool useVectorObs;
    Rigidbody m_AgentRb;
    int m_Selection;                  // 0=O가 정답, 1=X가 정답
    StatsRecorder m_statsRecorder;
}
```

#### Initialize() - 초기화
```csharp
public override void Initialize()
{
    m_HallwaySettings = FindFirstObjectByType<HallwaySettings>();
    m_AgentRb = GetComponent<Rigidbody>();
    m_GroundRenderer = ground.GetComponent<Renderer>();
    m_GroundMaterial = m_GroundRenderer.material;
    m_statsRecorder = Academy.Instance.StatsRecorder;
}
```

- `StatsRecorder`를 사용하여 올바른/잘못된 선택 통계 기록

#### CollectObservations() - 관찰 수집
```csharp
public override void CollectObservations(VectorSensor sensor)
{
    if (useVectorObs)
    {
        sensor.AddObservation(StepCount / (float)MaxStep);  // 경과 시간 비율
    }
}
```

**관찰 공간**: 1차원 (useVectorObs=true)
| 내용 | 설명 |
|------|------|
| StepCount / MaxStep | 현재 진행률 (0~1) |

시각 관찰(카메라)이 주요 관찰이며, 벡터 관찰은 시간 정보만 제공합니다.

#### MoveAgent() - 액션 처리
```csharp
public void MoveAgent(ActionSegment<int> act)
{
    var dirToGo = Vector3.zero;
    var rotateDir = Vector3.zero;
    var action = act[0];

    switch (action)
    {
        case 1: dirToGo = transform.forward * 1f; break;    // 전진
        case 2: dirToGo = transform.forward * -1f; break;   // 후진
        case 3: rotateDir = transform.up * 1f; break;       // 우회전
        case 4: rotateDir = transform.up * -1f; break;      // 좌회전
    }
    transform.Rotate(rotateDir, Time.deltaTime * 150f);
    m_AgentRb.AddForce(dirToGo * m_HallwaySettings.agentRunSpeed, ForceMode.VelocityChange);
}
```

**액션 공간**: 5개 이산 액션
| 액션 | 동작 |
|------|------|
| 0 | 정지 |
| 1 | 전진 |
| 2 | 후진 |
| 3 | 우회전 |
| 4 | 좌회전 |

#### OnActionReceived() - 보상
```csharp
public override void OnActionReceived(ActionBuffers actionBuffers)
{
    AddReward(-1f / MaxStep);  // 스텝 당 패널티
    MoveAgent(actionBuffers.DiscreteActions);
}
```

#### OnCollisionEnter() - 선택 판정
```csharp
void OnCollisionEnter(Collision col)
{
    if (col.gameObject.CompareTag("symbol_O_Goal") || col.gameObject.CompareTag("symbol_X_Goal"))
    {
        if ((m_Selection == 0 && col.gameObject.CompareTag("symbol_O_Goal")) ||
            (m_Selection == 1 && col.gameObject.CompareTag("symbol_X_Goal")))
        {
            SetReward(1f);   // 올바른 선택: +1
            m_statsRecorder.Add("Goal/Correct", 1, StatAggregationMethod.Sum);
        }
        else
        {
            SetReward(-0.1f); // 잘못된 선택: -0.1
            m_statsRecorder.Add("Goal/Wrong", 1, StatAggregationMethod.Sum);
        }
        EndEpisode();
    }
}
```

- 심볼과 일치하는 목표: +1 보상 + Correct 통계
- 심볼과 불일치하는 목표: -0.1 보상 + Wrong 통계

#### 목표와 심볼 위치 결정
```csharp
private void ChooseGoalAndSymbolPositions()
{
    m_Selection = Random.Range(0, 2);  // 0=O 정답, 1=X 정답
    
    // 정답 심볼만 표시 (보이는 위치), 오답 심볼은 숨김 (y=-1000)
    // m_Selection == 0: symbolO는 보이고, symbolX는 숨겨짐
    // m_Selection == 1: symbolX는 보이고, symbolO는 숨겨짐
    
    // 목표 위치도 좌우 랜덤
    var goalPos = Random.Range(0, 2);
    if (goalPos == 0)
    {
        symbolOGoal.transform.position = new Vector3(7f, 0.5f, 22.29f) + area.transform.position;
        symbolXGoal.transform.position = new Vector3(-7f, 0.5f, 22.29f) + area.transform.position;
    }
    else
    {
        symbolXGoal.transform.position = new Vector3(7f, 0.5f, 22.29f) + area.transform.position;
        symbolOGoal.transform.position = new Vector3(-7f, 0.5f, 22.29f) + area.transform.position;
    }
}
```

- 에이전트가 본 심볼과 목표 위치의 조합을 기억해야 하는 **작업 메모리** 과제
- 목표 위치(O가 왼쪽/X가 오른쪽 또는 반대)도 매 에피소드 랜덤

#### OnEpisodeBegin() - 에피소드 시작
```csharp
public override void OnEpisodeBegin()
{
    ChooseGoalAndSymbolPositions();
    
    transform.position = new Vector3(0f + Random.Range(-3f, 3f),
        1f, -15f + Random.Range(-5f, 5f)) + ground.transform.position;
    transform.rotation = Quaternion.Euler(0f, Random.Range(0f, 360f), 0f);
    m_AgentRb.linearVelocity *= 0f;
    
    m_statsRecorder.Add("Goal/Correct", 0, StatAggregationMethod.Sum);
    m_statsRecorder.Add("Goal/Wrong", 0, StatAggregationMethod.Sum);
}
```

### 2.2 HallwaySettings.cs

```csharp
public class HallwaySettings : MonoBehaviour
{
    public float agentRunSpeed;
    public float agentRotationSpeed;
    public Material goalScoredMaterial;
    public Material failMaterial;
}
```

---

## 3. 관찰-액션-보상 구조

| 항목 | 내용 |
|------|------|
| **관찰** | 1차원 (진행률) + Visual (카메라) |
| **액션** | 이산 5개 (전진/후진/좌회전/우회전/정지) |
| **보상** | 매 스텝 -1/MaxStep, 정답 +1, 오답 -0.1 |
| **종료 조건** | 목표 도달 시 |
| **핵심 과제** | **작업 메모리** - 본 심볼을 기억했다가 선택 |

### Memory 요구사항
- 에이전트는 에피소드 시작 시 본 심볼(O 또는 X)을 기억해야 함
- 목표 위치도 매번 변경되므로 위치 기억도 필요
- 관찰에 시간 정보만 있으므로 시각 정보 처리 및 기억이 필수

---

## 4. 학습 실행

### 4.1 학습 명령어
```bash
mlagents-learn config/ppo/Hallway.yaml --run-id=HallwayTest1
```

### 4.2 학습 설정
```yaml
behaviors:
  Hallway:
    trainer_type: ppo
    hyperparameters:
      batch_size: 1024
      buffer_size: 10240
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
      memory:
        sequence_length: 64
        memory_size: 256
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    max_steps: 10000000
    time_horizon: 128
    summary_freq: 30000
    keep_checkpoints: 5
```

**중요**: Hallway는 **메모리(memory)** 설정이 필요합니다.
- `memory_size: 256`으로 RNN 메모리 활성화
- 과거 관찰을 기억해야 작업을 해결할 수 있음

---

## 5. 실습 과제

### 과제 1: 메모리 유무 비교
- Memory 설정을 제거하고 학습하여 작업 기억의 중요성 확인
- Memory 유/무에 따른 학습 성능 비교 (Hallway는 메모리가 필수적)

### 과제 2: 심볼 관찰 방식 변경
- 벡터 관찰에 현재 표시된 심볼 정보를 직접 추가
  ```csharp
  sensor.AddObservation(m_Selection);  // 0=O, 1=X
  ```
- 벡터 관찰 추가 시 학습 속도 차이 분석

### 과제 3: 난이도 조절
- 목표 위치를 더 멀리 (y=30) 배치하여 복도 길이 증가
- 심볼 표시 시간을 제한하여 난이도 상승

### 과제 4: 세 가지 선택지
- O, X 외에 △(삼각형) 심볼과 목표를 추가하여 3-선택 문제로 확장

### 과제 5: StatsRecorder 분석
- TensorBoard에서 `Goal/Correct`와 `Goal/Wrong` 통계 확인
- 정답률이 학습 진행에 따라 어떻게 변화하는지 분석

---

## 6. 파일 구조

```
Hallway/
├── Scenes/
│   └── Hallway.unity
├── Scripts/
│   ├── HallwayAgent.cs       # 메인 에이전트
│   └── HallwaySettings.cs    # 설정
├── Prefabs/
│   └── HallwayArea.prefab
├── Meshes/
│   └── Ground.fbx
├── TFModels/
│   └── Hallway.onnx
└── Demos/
    └── ExpertHallway.demo
```

---

## 7. 핵심 포인트

- **작업 메모리(Working Memory)** 문제의 전형적인 예제
- `StatsRecorder`를 활용한 정답/오답 통계 추적
- 시각 관찰 + 벡터 관찰의 혼합 사용
- RNN 메모리(memory_size)의 중요성 입증
- 심볼과 목표 위치를 모두 기억해야 하는 복합 작업
- 오답에 대한 대칭적 보상 구조 (정답 +1, 오답 -0.1)
- TensorBoard에서 Correct/Wrong 비율로 학습 진행 모니터링
