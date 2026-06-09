# Worm 예제 가이드

## 1. 개요

Worm은 뱀/벌레 형태의 생명체가 기어서 움직이는 환경입니다.
Crawler나 Walker보다 단순한 구조(4개 바디 세그먼트)이지만, 지렁이처럼 몸을
구부리며 움직이는 독특한 보행 방식을 학습해야 합니다.

**목표**: 목표 지점을 향해 몸을 구부리며 앞으로 나아가기

### 학습 환경 구조

```
     [Target] ← 목표 지점
        ↑
   [Worm Agent] ← 4개 바디 세그먼트
   ○ → ○ → ○ → ○
  seg0  seg1  seg2  seg3
```

---

## 2. 코드 분석

### 2.1 WormAgent.cs

뱀/벌레 형태의 보행을 학습하는 에이전트입니다.

```csharp
[RequireComponent(typeof(JointDriveController))]
public class WormAgent : Agent
{
    const float m_MaxWalkingSpeed = 10;

    [Header("Target Prefabs")]
    public Transform TargetPrefab;
    private Transform m_Target;

    [Header("Body Parts")]
    public Transform bodySegment0;  // 머리
    public Transform bodySegment1;
    public Transform bodySegment2;
    public Transform bodySegment3;  // 꼬리

    OrientationCubeController m_OrientationCube;
    DirectionIndicator m_DirectionIndicator;
    JointDriveController m_JdController;
    private Vector3 m_StartingPos;
}
```

#### Initialize() - 4개 세그먼트 설정
```csharp
public override void Initialize()
{
    SpawnTarget(TargetPrefab, transform.position);
    m_StartingPos = bodySegment0.position;
    m_OrientationCube = GetComponentInChildren<OrientationCubeController>();
    m_DirectionIndicator = GetComponentInChildren<DirectionIndicator>();
    m_JdController = GetComponent<JointDriveController>();

    UpdateOrientationObjects();

    // 4개 바디 세그먼트 등록
    m_JdController.SetupBodyPart(bodySegment0);
    m_JdController.SetupBodyPart(bodySegment1);
    m_JdController.SetupBodyPart(bodySegment2);
    m_JdController.SetupBodyPart(bodySegment3);
}
```

#### OnEpisodeBegin() - 초기화
```csharp
public override void OnEpisodeBegin()
{
    foreach (var bodyPart in m_JdController.bodyPartsList)
        bodyPart.Reset(bodyPart);

    bodySegment0.rotation = Quaternion.Euler(0, Random.Range(0.0f, 360.0f), 0);
    UpdateOrientationObjects();
}
```

#### CollectObservationBodyPart() - 바디 파트 관찰
```csharp
public void CollectObservationBodyPart(BodyPart bp, VectorSensor sensor)
{
    sensor.AddObservation(bp.groundContact.touchingGround ? 1 : 0);

    // OrientationCube 기준 속도
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(bp.rb.linearVelocity));
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(bp.rb.angularVelocity));

    if (bp.rb.transform != bodySegment0)
    {
        // 머리 기준 상대 위치
        sensor.AddObservation(
            m_OrientationCube.transform.InverseTransformDirection(bp.rb.position - bodySegment0.position));
        sensor.AddObservation(bp.rb.transform.localRotation);
    }

    if (bp.joint)
        sensor.AddObservation(bp.currentStrength / m_JdController.maxJointForceLimit);
}
```

#### CollectObservations() - 전체 관찰
```csharp
public override void CollectObservations(VectorSensor sensor)
{
    RaycastHit hit;
    float maxDist = 10;
    if (Physics.Raycast(bodySegment0.position, Vector3.down, out hit, maxDist))
        sensor.AddObservation(hit.distance / maxDist);
    else
        sensor.AddObservation(1);

    var cubeForward = m_OrientationCube.transform.forward;
    var velGoal = cubeForward * m_MaxWalkingSpeed;
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(velGoal));
    sensor.AddObservation(Quaternion.Angle(m_OrientationCube.transform.rotation,
        m_JdController.bodyPartsDict[bodySegment0].rb.rotation) / 180);
    sensor.AddObservation(Quaternion.FromToRotation(bodySegment0.forward, cubeForward));

    sensor.AddObservation(m_OrientationCube.transform.InverseTransformPoint(m_Target.transform.position));

    foreach (var bodyPart in m_JdController.bodyPartsList)
        CollectObservationBodyPart(bodyPart, sensor);
}
```

**관찰 구조**: Crawler/Walker와 유사하지만 더 단순 (4개 바디 파트)
- 바닥까지 거리 (Raycast)
- 목표 속도 (OrientationCube 기준)
- 방향 각도 차이 (Quaternion.Angle 사용)
- 머리 방향 vs 목표 방향 차이
- 목표 위치
- 각 바디 파트별 접촉/속도/각속도/위치/회전/강도

#### OnActionReceived() - 6개 연속 액션
```csharp
public override void OnActionReceived(ActionBuffers actionBuffers)
{
    var bpDict = m_JdController.bodyPartsDict;
    var i = -1;
    var continuousActions = actionBuffers.ContinuousActions;

    // 3개 관절의 X/Z축 회전 목표 (6개 액션)
    bpDict[bodySegment0].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);
    bpDict[bodySegment1].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);
    bpDict[bodySegment2].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);

    // 3개 관절 강도 (3개 액션)
    bpDict[bodySegment0].SetJointStrength(continuousActions[++i]);
    bpDict[bodySegment1].SetJointStrength(continuousActions[++i]);
    bpDict[bodySegment2].SetJointStrength(continuousActions[++i]);

    // 바닥 아래로 떨어졌는지 확인
    if (bodySegment0.position.y < m_StartingPos.y - 2)
        EndEpisode();
}
```

**액션 공간**: 9차원 연속
| 액션 범위 | 개수 | 설명 |
|-----------|------|------|
| 관절 회전 목표 (X, Z) | 6 | 3개 관절(seg0→seg1, seg1→seg2, seg2→seg3) × 2축 |
| 관절 강도 | 3 | 3개 관절의 강도 |

#### FixedUpdate() - 보상 계산
```csharp
void FixedUpdate()
{
    UpdateOrientationObjects();

    var velReward = GetMatchingVelocityReward(
        m_OrientationCube.transform.forward * m_MaxWalkingSpeed,
        m_JdController.bodyPartsDict[bodySegment0].rb.linearVelocity);

    var rotAngle = Quaternion.Angle(m_OrientationCube.transform.rotation,
        m_JdController.bodyPartsDict[bodySegment0].rb.rotation);

    var facingRew = 0f;
    if (rotAngle < 30)  // 30도 이내일 때만 방향 보상
        facingRew = 1 - (rotAngle / 180);

    AddReward(velReward * facingRew);
}
```

**보상 체계**:
- `velReward`: 속도 일치도 (Crawler/Walker와 동일한 S자형 곡선)
- `facingRew`: 방향 정렬도 (30도 이내일 때만, 최대 1)
- **차이점**: 30도 이내에서만 방향 보상이 활성화됨 (Crawler/Walker는 항상 활성화)

---

## 3. Crawler vs Walker vs Worm 비교

| 특징 | Crawler | Walker | Worm |
|------|---------|--------|------|
| **형태** | 4족 (거미) | 2족 (인간) | 뱀/벌레 |
| **바디 파트** | 8개 | 15개 | 4개 |
| **관절 수** | 8개 (다리) | ~14개 | 3개 |
| **액션 차원** | 20 | ~28 | 9 |
| **학습 난이도** | 중간 | 높음 | 낮음 (상대적) |
| **방향 보상** | 항상 활성화 | 항상 활성화 | 30도 이내만 |
| **넘어짐 감지** | 없음 | 없음 | 있음 (y-2) |

---

## 4. 학습 실행

### 4.1 학습 명령어
```bash
mlagents-learn config/ppo/Worm.yaml --run-id=WormTest1
```

### 4.2 학습 설정
```yaml
behaviors:
  Worm:
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
      hidden_units: 128
      num_layers: 2
    reward_signals:
      extrinsic:
        gamma: 0.995
        strength: 1.0
    max_steps: 5000000
    time_horizon: 1000
    summary_freq: 30000
    keep_checkpoints: 5
```

---

## 5. 실습 과제

### 과제 1: 더 많은 세그먼트
- body segment를 4개에서 6개, 8개로 늘려보기
- `SetupBodyPart()`에 추가하고 액션 공간 확장
- 세그먼트 수 증가에 따른 학습 난이도 변화 관찰

### 과제 2: 방향 보상 임계값 변경
- `rotAngle < 30` 조건을 `rotAngle < 60` 또는 `rotAngle < 10`으로 변경
- 임계값이 학습 속도와 안정성에 미치는 영향 분석

### 과제 3: Crawler 방식 적용
- Worm의 보상 체계를 Crawler와 동일하게 변경 (항상 방향 보상)
- 30도 제한의 효과 비교 분석

### 과제 4: 속도 가변 학습
- `randomizeWalkSpeedEachEpisode` 기능을 추가하여 다양한 속도 학습
- Worm의 최대 속도 한계 실험 (m_MaxWalkingSpeed 증가)

### 과제 5: 기어가는 시각화
- `useFootGroundedVisualization` 같은 시각화 기능 추가
- 바디 세그먼트의 지면 접촉 상태를 색상으로 표시

---

## 6. 파일 구조

```
Worm/
├── Scenes/
│   └── Worm.unity
├── Scripts/
│   └── WormAgent.cs               # 메인 에이전트
├── Prefabs/
│   ├── PlatformWorm.prefab
│   └── Worm.prefab
├── TFModels/
│   └── Worm.onnx
```

---

## 7. 핵심 포인트

- 뱀/벌레형 **사행 보행(Serpentine Locomotion)** 학습
- 가장 단순한 바디 구조 (4개 세그먼트, 3개 관절)
- Crawler/Walker와 동일한 `JointDriveController`, `OrientationCubeController` 사용
- 30도 이내에서만 방향 보상이 활성화되는 독특한 보상 체계
- 바닥 아래로 떨어짐 감지 (넘어짐/추락 처리)
- 단순한 구조에서도 효과적인 보행 패턴 학습 가능
- Quaternion.Angle을 사용한 방향 각도 계산
- 다른 locomotion 예제와의 비교를 통한 RL 아키텍처 이해
