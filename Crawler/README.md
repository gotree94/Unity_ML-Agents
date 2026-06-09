# Crawler 예제 가이드

## 1. 개요

Crawler는 4족 보행 로봇(거미형)이 목표 지점을 향해 걷도록 학습하는 환경입니다.
크롤러는 8개의 관절(다리당 2개: 상부/하부)을 가지고 있으며, 각 관절의 회전각과 강도를
연속적으로 제어하여 앞으로 나아가야 합니다.

**목표**: 목표 지점을 향해 앞으로 나아가기 (목표 속도에 맞춰 이동)

### 학습 환경 구조

```
     [Target] ← 목표 지점
        ↑
  [Crawler Agent]
   /  |  |  \        ← 4개의 다리 (각 2개의 관절)
  leg0 leg1 leg2 leg3
```

---

## 2. 코드 분석

### 2.1 CrawlerAgent.cs

4족 보행을 학습하는 메인 에이전트입니다.

```csharp
[RequireComponent(typeof(JointDriveController))]
public class CrawlerAgent : Agent
{
    [Header("Walk Speed")]
    [Range(0.1f, m_maxWalkingSpeed)]
    public float TargetWalkingSpeed { get; set; }
    const float m_maxWalkingSpeed = 15;

    [Header("Target To Walk Towards")]
    public Transform TargetPrefab;
    private Transform m_Target;

    [Header("Body Parts")]
    public Transform body;
    public Transform leg0Upper, leg0Lower;
    public Transform leg1Upper, leg1Lower;
    public Transform leg2Upper, leg2Lower;
    public Transform leg3Upper, leg3Lower;

    OrientationCubeController m_OrientationCube;
    DirectionIndicator m_DirectionIndicator;
    JointDriveController m_JdController;
}
```

#### Initialize() - 8개 관절 설정
```csharp
public override void Initialize()
{
    SpawnTarget(TargetPrefab, transform.position);  // 목표 위치 생성
    m_OrientationCube = GetComponentInChildren<OrientationCubeController>();
    m_DirectionIndicator = GetComponentInChildren<DirectionIndicator>();
    m_JdController = GetComponent<JointDriveController>();

    // 8개 바디 파트 설정 (body + 4개 다리 × 2개 관절)
    m_JdController.SetupBodyPart(body);
    m_JdController.SetupBodyPart(leg0Upper);
    m_JdController.SetupBodyPart(leg0Lower);
    m_JdController.SetupBodyPart(leg1Upper);
    m_JdController.SetupBodyPart(leg1Lower);
    m_JdController.SetupBodyPart(leg2Upper);
    m_JdController.SetupBodyPart(leg2Lower);
    m_JdController.SetupBodyPart(leg3Upper);
    m_JdController.SetupBodyPart(leg3Lower);
}
```

#### OnEpisodeBegin() - 초기화
```csharp
public override void OnEpisodeBegin()
{
    foreach (var bodyPart in m_JdController.bodyPartsDict.Values)
        bodyPart.Reset(bodyPart);

    // 랜덤 시작 회전 (일반화 학습)
    body.rotation = Quaternion.Euler(0, Random.Range(0.0f, 360.0f), 0);

    UpdateOrientationObjects();

    // 목표 속도 랜덤 설정 (0.1 ~ 15)
    TargetWalkingSpeed = Random.Range(0.1f, m_maxWalkingSpeed);
}
```

#### CollectObservations() - 8개 바디 파트별 관찰
```csharp
public void CollectObservationBodyPart(BodyPart bp, VectorSensor sensor)
{
    sensor.AddObservation(bp.groundContact.touchingGround);  // 땅에 닿았는가
    if (bp.rb.transform != body)
        sensor.AddObservation(bp.currentStrength / m_JdController.maxJointForceLimit);  // 관절 강도
}

public override void CollectObservations(VectorSensor sensor)
{
    var cubeForward = m_OrientationCube.transform.forward;
    var velGoal = cubeForward * TargetWalkingSpeed;
    var avgVel = GetAvgVelocity();

    sensor.AddObservation(Vector3.Distance(velGoal, avgVel));  // 속도 차이
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(avgVel));
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(velGoal));
    sensor.AddObservation(Quaternion.FromToRotation(body.forward, cubeForward));  // 방향 차이

    // 목표 위치 (OrientationCube 기준)
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformPoint(m_Target.transform.position));

    // 바닥까지 거리 (Raycast)
    RaycastHit hit;
    if (Physics.Raycast(body.position, Vector3.down, out hit, 10))
        sensor.AddObservation(hit.distance / 10);
    else
        sensor.AddObservation(1);

    // 각 바디 파트별 관찰
    foreach (var bodyPart in m_JdController.bodyPartsList)
        CollectObservationBodyPart(bodyPart, sensor);
}
```

**총 관찰 차원**: 약 20차원 이상 (8개 바디 파트 × 각 2개 값 + 6개 공통 값)

#### OnActionReceived() - 16개 연속 액션으로 8개 관절 제어
```csharp
public override void OnActionReceived(ActionBuffers actionBuffers)
{
    var bpDict = m_JdController.bodyPartsDict;
    var continuousActions = actionBuffers.ContinuousActions;
    var i = -1;

    // 각 다리의 상부 관절: X/Z축 회전 목표 설정 (8개 액션)
    bpDict[leg0Upper].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);
    bpDict[leg1Upper].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);
    bpDict[leg2Upper].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);
    bpDict[leg3Upper].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);

    // 각 다리의 하부 관절: X축 회전 목표 설정 (4개 액션)
    bpDict[leg0Lower].SetJointTargetRotation(continuousActions[++i], 0, 0);
    bpDict[leg1Lower].SetJointTargetRotation(continuousActions[++i], 0, 0);
    bpDict[leg2Lower].SetJointTargetRotation(continuousActions[++i], 0, 0);
    bpDict[leg3Lower].SetJointTargetRotation(continuousActions[++i], 0, 0);

    // 각 관절의 강도 설정 (8개 액션)
    bpDict[leg0Upper].SetJointStrength(continuousActions[++i]);
    bpDict[leg1Upper].SetJointStrength(continuousActions[++i]);
    bpDict[leg2Upper].SetJointStrength(continuousActions[++i]);
    bpDict[leg3Upper].SetJointStrength(continuousActions[++i]);
    bpDict[leg0Lower].SetJointStrength(continuousActions[++i]);
    bpDict[leg1Lower].SetJointStrength(continuousActions[++i]);
    bpDict[leg2Lower].SetJointStrength(continuousActions[++i]);
    bpDict[leg3Lower].SetJointStrength(continuousActions[++i]);
}
```

**액션 공간**: 20차원 연속(Continuous) 액션
| 액션 범위 | 개수 | 설명 |
|-----------|------|------|
| 관절 회전 목표 (X, Z) | 8 | 4개 상부 다리 × 2축 |
| 관절 회전 목표 (X) | 4 | 4개 하부 다리 × 1축 |
| 관절 강도 | 8 | 모든 관절의 강도 (0~1) |

#### FixedUpdate() - 보상 계산
```csharp
void FixedUpdate()
{
    UpdateOrientationObjects();

    var cubeForward = m_OrientationCube.transform.forward;

    // a. 속도 일치 보상: 목표 속도와 실제 속도의 차이에 따른 S자형 곡선
    var matchSpeedReward = GetMatchingVelocityReward(cubeForward * TargetWalkingSpeed, GetAvgVelocity());

    // b. 방향 정렬 보상: 목표 방향을 바라보는 정도
    var lookAtTargetReward = (Vector3.Dot(cubeForward, body.forward) + 1) * .5F;

    AddReward(matchSpeedReward * lookAtTargetReward);
}
```

- **보상 = 속도_일치도 × 방향_정렬도** (두 요소의 곱)
- 속도 일치도: 0~1 사이의 S자형 곡선 (완전 일치=1)
- 방향 정렬도: 0~1 (정면=1, 반대=0)

#### GetMatchingVelocityReward() - 속도 일치 보상
```csharp
public float GetMatchingVelocityReward(Vector3 velocityGoal, Vector3 actualVelocity)
{
    var velDeltaMagnitude = Mathf.Clamp(
        Vector3.Distance(actualVelocity, velocityGoal), 0, TargetWalkingSpeed);
    return Mathf.Pow(1 - Mathf.Pow(velDeltaMagnitude / TargetWalkingSpeed, 2), 2);
}
```

- S자형 감소 곡선: 속도 차이가 0에 가까우면 1, 차이가 커질수록 0에 수렴
- 속도 차이를 목표 속도로 정규화

#### GetAvgVelocity() - 바디 파트 평균 속도
```csharp
Vector3 GetAvgVelocity()
{
    Vector3 velSum = Vector3.zero;
    int numOfRb = 0;
    foreach (var item in m_JdController.bodyPartsList)
    {
        numOfRb++;
        velSum += item.rb.linearVelocity;
    }
    return velSum / numOfRb;
}
```

- 모든 바디 파트의 속도를 평균내어 사용
- 바디만의 속도를 사용하면 팔다리가 과도하게 흔들리는 현상 방지

#### Foot Grounded Visualization
```csharp
if (useFootGroundedVisualization)
{
    foot0.material = m_JdController.bodyPartsDict[leg0Lower].groundContact.touchingGround
        ? groundedMaterial : unGroundedMaterial;
    // ... 각 발마다 동일
}
```

---

## 3. 관찰-액션-보상 구조

| 항목 | 내용 |
|------|------|
| **관찰** | 20차원+ (목표 속도 차이, 방향, 바디파트별 접촉/강도) |
| **액션** | 20차원 연속 (관절 회전 각도 + 강도) |
| **보상** | 매 스텝: 속도_일치도 × 방향_정렬도 |
| **종료 조건** | MaxStep 도달 |
| **특징** | OrientationCube, JointDriveController 사용 |

---

## 4. 학습 실행

### 4.1 학습 명령어
```bash
mlagents-learn config/ppo/Crawler.yaml --run-id=CrawlerTest1
```

### 4.2 학습 설정
```yaml
behaviors:
  Crawler:
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
      normalize: true
      hidden_units: 256
      num_layers: 3
    reward_signals:
      extrinsic:
        gamma: 0.995
        strength: 1.0
    max_steps: 10000000
    time_horizon: 1000
    summary_freq: 30000
    keep_checkpoints: 5
```

**중요 설정**:
- `normalize: true` - 관찰 정규화 필수 (다양한 물리 값)
- `hidden_units: 256`, `num_layers: 3` - 복잡한 보행 패턴 학습에 충분한 용량
- `time_horizon: 1000` - 긴 시퀀스 고려
- `gamma: 0.995` - 먼 미래 보상도 고려

---

## 5. 실습 과제

### 과제 1: 보행 속도 최적화
- `m_maxWalkingSpeed`를 15에서 10, 20으로 변경하여 최적 속도 찾기
- 속도가 너무 빠르면 학습이 불안정해지는 현상 관찰

### 과제 2: 관절 구조 변경
- 다리당 관절을 3개로 늘리거나 1개로 줄여서 학습 난이도 비교
- 관절이 많을수록 더 유연한 움직임이 가능하지만 학습은 더 어려워짐

### 과제 3: 바닥 마찰력 변경
- `EnvironmentParameters`를 사용하여 바닥 마찰력을 동적으로 변경
- Curriculum Learning: 미끄러운 바닥 → 일반 바닥 → 거친 바닥

### 과제 4: TargetWalkingSpeed 고정
- `randomizeWalkSpeedEachEpisode` 기능을 추가하여 속도 고정/랜덤 비교
- 특정 속도에 특화된 보행 vs 다양한 속도를 커버하는 일반화된 보행

### 과제 5: OrientationCube 제거
- `OrientationCubeController` 없이 월드 좌표계 기준으로 학습
- OrientationCube가 학습 안정성에 미치는 영향 분석

---

## 6. 파일 구조

```
Crawler/
├── Scenes/
│   └── Crawler.unity
├── Scripts/
│   └── CrawlerAgent.cs            # 메인 에이전트
├── Prefabs/
│   ├── Crawler.prefab
│   └── Platform.prefab
├── TFModels/
│   └── Crawler.onnx
└── Demos/
    └── ExpertCrawler.demo
```

---

## 7. 핵심 포인트

- **4족 보행** 로봇 제어의 전형적인 RL 문제
- `JointDriveController`로 관절 물리 제어 (회전 목표 + 강도)
- `OrientationCubeController`로 안정적인 모델 공간 기준 제공
- **16개 연속 액션**으로 8개 관절의 3개 파라미터(회전X, 회전Z, 강도) 제어
- 평균 속도를 보상에 사용하여 과도한 limb 움직임 억제
- 보상 = 속도_일치도 × 방향_정렬도 (두 요소의 곱)
- S자형 보상 함수로 부드러운 학습 유도
- Foot Grounded 시각화로 학습 과정 모니터링
- 랜덤 시작 방향과 속도로 일반화 학습 촉진
