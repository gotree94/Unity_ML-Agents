# FoodCollector 예제 가이드

## 1. 개요

FoodCollector는 여러 에이전트가 경쟁하며 음식을 수집하는 다중 에이전트 환경입니다.
좋은 음식(good food)을 먹으면 보상을 받고, 나쁜 음식(bad food)을 먹으면
벌점을 받습니다. 또한 레이저를 발사하여 다른 에이전트를 일시적으로 얼릴 수 있습니다.

**목표**: 좋은 음식을 최대한 많이 먹고, 나쁜 음식과 얼어붙는 것을 피하기

### 학습 환경 구조

```
  [FoodCollectorArea]
  ┌─────────────────────────────┐
  │   f₁    f₂    b₁    f₃      │  ← 에이전트 + 음식 배치
  │   A₁          A₂            │
  │   b₂         f₄             │
  │   A₃                f₅      │
  └─────────────────────────────┘
  f: 좋은 음식, b: 나쁜 음식, A: 에이전트
```

---

## 2. 코드 분석

### 2.1 FoodCollectorAgent.cs

음식을 수집하는 메인 에이전트입니다.

```csharp
public class FoodCollectorAgent : Agent
{
    FoodCollectorSettings m_FoodCollecterSettings;
    public GameObject area;
    FoodCollectorArea m_MyArea;
    bool m_Frozen;       // 얼어붙음 상태
    bool m_Poisoned;     // 중독 상태
    bool m_Satiated;     // 만족 상태
    bool m_Shoot;        // 레이저 발사 여부
    float m_FrozenTime;
    float m_EffectTime;
    Rigidbody m_AgentRb;
    float m_LaserLength;

    public float turnSpeed = 300;
    public float moveSpeed = 2;
    public Material normalMaterial;
    public Material badMaterial;
    public Material goodMaterial;
    public Material frozenMaterial;
    public GameObject myLaser;
    public bool contribute;
    public bool useVectorObs;
    public bool useVectorFrozenFlag;
}
```

#### States (4가지 상태)

| 상태 | 변수 | 효과 | 전환 조건 |
|------|------|------|-----------|
| Normal | (기본) | 정상 이동 | 초기 상태 |
| Frozen | `m_Frozen` | 이동 불가 | Freeze() 호출, 4초 후 Unfreeze() |
| Poisoned | `m_Poisoned` | 시각적 표시 (빨강) | 나쁜 음식 섭취, 0.5초 후 Unpoison() |
| Satiated | `m_Satiated` | 시각적 표시 (초록) | 좋은 음식 섭취, 0.5초 후 Unsatiate() |

#### CollectObservations() - 관찰
```csharp
public override void CollectObservations(VectorSensor sensor)
{
    if (useVectorObs)
    {
        var localVelocity = transform.InverseTransformDirection(m_AgentRb.linearVelocity);
        sensor.AddObservation(localVelocity.x);
        sensor.AddObservation(localVelocity.z);
        sensor.AddObservation(m_Frozen);
        sensor.AddObservation(m_Shoot);
    }
    else if (useVectorFrozenFlag)
    {
        sensor.AddObservation(m_Frozen);
    }
}
```

**관찰 모드 (3가지)**:
- `useVectorObs=true`: 속도(x,z) + 얼음 + 발사 → 4차원
- `useVectorObs=false` + `useVectorFrozenFlag=true`: 얼음 상태만 → 1차원
- 둘 다 false: 시각 관찰만 사용 (VisualFoodCollector)

#### MoveAgent() - 하이브리드 액션 (연속 + 이산)
```csharp
public void MoveAgent(ActionBuffers actionBuffers)
{
    m_Shoot = false;

    // 상태 타이머 처리
    if (Time.time > m_FrozenTime + 4f && m_Frozen) Unfreeze();
    if (Time.time > m_EffectTime + 0.5f)
    {
        if (m_Poisoned) Unpoison();
        if (m_Satiated) Unsatiate();
    }

    var continuousActions = actionBuffers.ContinuousActions;
    var discreteActions = actionBuffers.DiscreteActions;

    if (!m_Frozen)
    {
        // 연속 액션: 전진/후진(0), 좌우(1), 회전(2)
        var forward = Mathf.Clamp(continuousActions[0], -1f, 1f);
        var right = Mathf.Clamp(continuousActions[1], -1f, 1f);
        var rotate = Mathf.Clamp(continuousActions[2], -1f, 1f);

        dirToGo = transform.forward * forward + transform.right * right;
        rotateDir = -transform.up * rotate;

        // 이산 액션: 발사 (0 또는 1)
        var shootCommand = discreteActions[0] > 0;
        if (shootCommand)
        {
            m_Shoot = true;
            dirToGo *= 0.5f;       // 발사 중 이동 감소
            m_AgentRb.linearVelocity *= 0.75f;
        }

        m_AgentRb.AddForce(dirToGo * moveSpeed, ForceMode.VelocityChange);
        transform.Rotate(rotateDir, Time.fixedDeltaTime * turnSpeed);
    }

    // 속도 제한
    if (m_AgentRb.linearVelocity.sqrMagnitude > 25f)
        m_AgentRb.linearVelocity *= 0.95f;

    // 레이저 처리
    if (m_Shoot)
    {
        myLaser.transform.localScale = new Vector3(1f, 1f, m_LaserLength);
        if (Physics.SphereCast(transform.position, 2f, rayDir, out hit, 25f))
        {
            if (hit.collider.gameObject.CompareTag("agent"))
                hit.collider.gameObject.GetComponent<FoodCollectorAgent>().Freeze();
        }
    }
    else
        myLaser.transform.localScale = Vector3.zero;
}
```

**액션 공간**:
| 액션 타입 | 차원 | 범위 | 설명 |
|-----------|------|------|------|
| Continuous | 3 | [-1, 1] | 전진/후진, 좌우, 회전 |
| Discrete | 1 | {0, 1} | 발사 (0=안함, 1=발사) |

#### OnCollisionEnter() - 보상
```csharp
void OnCollisionEnter(Collision collision)
{
    if (collision.gameObject.CompareTag("food"))
    {
        Satiate();
        collision.gameObject.GetComponent<FoodLogic>().OnEaten();
        AddReward(1f);          // 좋은 음식 +1
        if (contribute) m_FoodCollecterSettings.totalScore += 1;
    }
    if (collision.gameObject.CompareTag("badFood"))
    {
        Poison();
        collision.gameObject.GetComponent<FoodLogic>().OnEaten();
        AddReward(-1f);         // 나쁜 음식 -1
        if (contribute) m_FoodCollecterSettings.totalScore -= 1;
    }
}
```

#### Freeze/Poison/Satiate - 상태 전환
```csharp
void Freeze() {
    gameObject.tag = "frozenAgent";
    m_Frozen = true;
    m_FrozenTime = Time.time;
    // 보라색 머티리얼
}

void Poison() {
    m_Poisoned = true;
    m_EffectTime = Time.time;
    // 빨간색 머티리얼
}

void Satiate() {
    m_Satiated = true;
    m_EffectTime = Time.time;
    // 초록색 머티리얼
}
```

### 2.2 FoodCollectorArea.cs

음식들을 생성하고 리셋하는 영역 관리자입니다.

```csharp
public class FoodCollectorArea : Area
{
    public GameObject food;
    public GameObject badFood;
    public int numFood;
    public int numBadFood;
    public bool respawnFood;
    public float range;

    void CreateFood(int num, GameObject type)
    {
        for (int i = 0; i < num; i++)
        {
            GameObject f = Instantiate(type, new Vector3(
                Random.Range(-range, range), 1f,
                Random.Range(-range, range)) + transform.position,
                Quaternion.Euler(0f, Random.Range(0f, 360f), 90f));
            f.GetComponent<FoodLogic>().respawn = respawnFood;
            f.GetComponent<FoodLogic>().myArea = this;
        }
    }

    public void ResetFoodArea(GameObject[] agents)
    {
        // 에이전트 위치 리셋
        foreach (GameObject agent in agents)
        {
            if (agent.transform.parent == gameObject.transform)
            {
                agent.transform.position = new Vector3(...);
                agent.transform.rotation = Quaternion.Euler(...);
            }
        }
        CreateFood(numFood, food);      // 좋은 음식 생성
        CreateFood(numBadFood, badFood); // 나쁜 음식 생성
    }
}
```

### 2.3 FoodCollectorSettings.cs

에피소드 리셋 및 점수 집계 관리자입니다.

```csharp
public class FoodCollectorSettings : MonoBehaviour
{
    public int totalScore;
    public Text scoreText;
    StatsRecorder m_Recorder;

    void EnvironmentReset()
    {
        ClearObjects(GameObject.FindGameObjectsWithTag("food"));
        ClearObjects(GameObject.FindGameObjectsWithTag("badFood"));
        // 에이전트와 영역 찾아서 리셋
        foreach (var fa in listArea)
            fa.ResetFoodArea(agents);
        totalScore = 0;
    }

    public void Update()
    {
        scoreText.text = $"Score: {totalScore}";
        if ((Time.frameCount % 100) == 0)
            m_Recorder.Add("TotalScore", totalScore);  // TensorBoard 전송
    }
}
```

### 2.4 FoodLogic.cs

개별 음식 조각의 로직입니다.

```csharp
public class FoodLogic : MonoBehaviour
{
    public bool respawn;
    public FoodCollectorArea myArea;

    public void OnEaten()
    {
        if (respawn)
            transform.position = new Vector3(...);  // 새 위치에서 리스폰
        else
            Destroy(gameObject);                     // 영구 제거
    }
}
```

---

## 3. 관찰-액션-보상 구조

| 항목 | 내용 |
|------|------|
| **관찰** | Vector: 속도(x,z) + 상태(frozen, shoot) = 4차원 / 또는 시각 관찰 |
| **액션** | 연속 3차원(방향) + 이산 1차원(발사) |
| **보상** | 좋은 음식 +1, 나쁜 음식 -1 |
| **종료 조건** | MaxStep 도달 |
| **특징** | 다중 에이전트, PvP 요소 (얼리기) |

---

## 4. 학습 실행

### 4.1 학습 명령어
```bash
mlagents-learn config/ppo/FoodCollector.yaml --run-id=FoodCollectorTest1
```

### 4.2 학습 설정
```yaml
behaviors:
  FoodCollector:
    trainer_type: ppo
    hyperparameters:
      batch_size: 128
      buffer_size: 2048
      learning_rate: 3.0e-4
      beta: 5.0e-4
      epsilon: 0.2
      lambd: 0.99
      num_epoch: 3
      learning_rate_schedule: linear
    network_settings:
      normalize: false
      hidden_units: 256
      num_layers: 2
    reward_signals:
      extrinsic:
        gamma: 0.99
        strength: 1.0
    max_steps: 5000000
    time_horizon: 64
    summary_freq: 10000
    keep_checkpoints: 5
```

---

## 5. 실습 과제

### 과제 1: Curriculum Learning
- `laser_length`와 `agent_scale` 파라미터를 사용한 커리큘럼 학습
- 짧은 레이저 → 긴 레이저, 큰 에이전트 → 작은 에이전트

### 과제 2: 보상 조정
- 좋은 음식 보상을 +1에서 +2로, 나쁜 음식 패널티를 -1에서 -0.5로 변경
- 전략 변화 관찰 (위험 감수 행동)

### 과제 3: 팀 협력 학습
- `contribute` 플래그를 사용한 협력/경쟁 비교
- 개인 점수(totalScore 미포함) vs 팀 점수(totalScore 포함) 비교

### 과제 4: 시각 관찰 학습
- `useVectorObs = false`로 설정하여 시각 관찰만으로 학습
- 벡터 관찰 vs 시각 관찰 성능 비교

### 과제 5: 얼음 상태 전략
- Freeze 지속 시간(4초)을 변경하여 게임 밸런스 조정
- 얼음 해제 후 재사용 대기시간 추가

---

## 6. 파일 구조

```
FoodCollector/
├── Scenes/
│   ├── FoodCollector.unity
│   └── VisualFoodCollector.unity
├── Scripts/
│   ├── FoodCollectorAgent.cs        # 메인 에이전트
│   ├── FoodCollectorArea.cs         # 영역 관리
│   ├── FoodCollectorSettings.cs     # 전역 설정
│   └── FoodLogic.cs                 # 음식 로직
├── Prefabs/
│   └── FoodCollectorArea.prefab
├── TFModels/
│   └── FoodCollector.onnx
└── Demos/
    └── ExpertFoodCollector.demo
```

---

## 7. 핵심 포인트

- **다중 에이전트 경쟁** 환경 (PvP 요소 포함)
- **하이브리드 액션 공간**: 연속(이동) + 이산(발사)
- **4가지 상태**: Normal, Frozen, Poisoned, Satiated
- 레이저 발사로 상대 에이전트를 일시적으로 무력화
- 음식 리스폰 옵션 (`respawnFood`) 으로 난이도 조절
- 총점(totalScore)을 TensorBoard로 시각화
- Curriculum Learning 지원 (`laser_length`, `agent_scale`)
- 시각 관찰(Visual) 버전과 벡터 관찰 버전 모두 제공
- 프레임 기반 StatsRecorder로 TensorBoard 전송
