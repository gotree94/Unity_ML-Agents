# Walker 예제 가이드

## 1. 개요

Walker는 인간형 2족 보행 로봇이 목표 지점을 향해 걷도록 학습하는 환경입니다.
크롤러보다 더 많은 관절(15개 바디 파트, 약 28개 관절 파라미터)을 가지고 있어
더 복잡한 보행 패턴이 필요합니다.

**목표**: 인간형 로봇이 안정적으로 목표 지점까지 걸어가기

### 학습 환경 구조

```
     [Target] ← 목표 지점
        ↑
   [Walker Agent] ← 인간형 2족 보행 로봇
   머리, 상체, 하체, 양팔, 양다리 (15개 바디 파트)
```

---

## 2. 코드 분석

### 2.1 WalkerAgent.cs

인간형 2족 보행을 학습하는 에이전트입니다.

```csharp
public class WalkerAgent : Agent
{
    [Range(0.1f, 10)]
    public float MTargetWalkingSpeed { get; set; }
    const float m_maxWalkingSpeed = 10;
    public bool randomizeWalkSpeedEachEpisode;
    public Transform target;

    [Header("Body Parts")]
    public Transform hips, chest, spine, head;
    public Transform thighL, shinL, footL;
    public Transform thighR, shinR, footR;
    public Transform armL, forearmL, handL;
    public Transform armR, forearmR, handR;

    OrientationCubeController m_OrientationCube;
    DirectionIndicator m_DirectionIndicator;
    JointDriveController m_JdController;
    EnvironmentParameters m_ResetParams;
}
```

#### Initialize() - 15개 바디 파트 설정
```csharp
public override void Initialize()
{
    m_OrientationCube = GetComponentInChildren<OrientationCubeController>();
    m_DirectionIndicator = GetComponentInChildren<DirectionIndicator>();
    m_JdController = GetComponent<JointDriveController>();

    // 15개 바디 파트 등록
    m_JdController.SetupBodyPart(hips);
    m_JdController.SetupBodyPart(chest);
    m_JdController.SetupBodyPart(spine);
    m_JdController.SetupBodyPart(head);
    m_JdController.SetupBodyPart(thighL);
    m_JdController.SetupBodyPart(shinL);
    m_JdController.SetupBodyPart(footL);
    m_JdController.SetupBodyPart(thighR);
    m_JdController.SetupBodyPart(shinR);
    m_JdController.SetupBodyPart(footR);
    m_JdController.SetupBodyPart(armL);
    m_JdController.SetupBodyPart(forearmL);
    m_JdController.SetupBodyPart(handL);
    m_JdController.SetupBodyPart(armR);
    m_JdController.SetupBodyPart(forearmR);
    m_JdController.SetupBodyPart(handR);

    m_ResetParams = Academy.Instance.EnvironmentParameters;
}
```

#### OnEpisodeBegin() - 에피소드 시작
```csharp
public override void OnEpisodeBegin()
{
    foreach (var bodyPart in m_JdController.bodyPartsDict.Values)
        bodyPart.Reset(bodyPart);

    // 랜덤 시작 방향
    hips.rotation = Quaternion.Euler(0, Random.Range(0.0f, 360.0f), 0);

    UpdateOrientationObjects();

    // 목표 속도 랜덤 설정 (선택시)
    MTargetWalkingSpeed = randomizeWalkSpeedEachEpisode
        ? Random.Range(0.1f, m_maxWalkingSpeed)
        : MTargetWalkingSpeed;
}
```

#### CollectObservationBodyPart() - 바디 파트별 관찰
```csharp
public void CollectObservationBodyPart(BodyPart bp, VectorSensor sensor)
{
    sensor.AddObservation(bp.groundContact.touchingGround);

    // OrientationCube 기준 속도
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(bp.rb.linearVelocity));
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(bp.rb.angularVelocity));

    // OrientationCube 기준 위치 (hips 기준)
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(bp.rb.position - hips.position));

    if (bp.rb.transform != hips && bp.rb.transform != handL && bp.rb.transform != handR)
    {
        sensor.AddObservation(bp.rb.transform.localRotation);
        sensor.AddObservation(bp.currentStrength / m_JdController.maxJointForceLimit);
    }
}
```

- 15개 바디 파트 각각에 대해 접촉, 속도, 각속도, 상대 위치, 회전, 강도 관찰
- hands(handL, handR)는 localRotation과 strength를 제외 (불필요한 정보)

#### CollectObservations() - 전체 관찰 통합
```csharp
public override void CollectObservations(VectorSensor sensor)
{
    var cubeForward = m_OrientationCube.transform.forward;
    var velGoal = cubeForward * MTargetWalkingSpeed;
    var avgVel = GetAvgVelocity();

    sensor.AddObservation(Vector3.Distance(velGoal, avgVel));
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(avgVel));
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformDirection(velGoal));

    // 방향 차이 (hips와 head 각각)
    sensor.AddObservation(Quaternion.FromToRotation(hips.forward, cubeForward));
    sensor.AddObservation(Quaternion.FromToRotation(head.forward, cubeForward));

    // 목표 위치
    sensor.AddObservation(m_OrientationCube.transform.InverseTransformPoint(target.transform.position));

    // 각 바디 파트
    foreach (var bodyPart in m_JdController.bodyPartsList)
        CollectObservationBodyPart(bodyPart, sensor);
}
```

**총 관찰 차원**: 약 60~70차원
- 6개 공통 값 (속도 차이, 평균 속도, 목표 속도, 방향×2, 목표 위치)
- 15개 바디 파트 × 각 3~5개 값

#### OnActionReceived() - 약 28개 연속 액션
```csharp
public override void OnActionReceived(ActionBuffers actionBuffers)
{
    var bpDict = m_JdController.bodyPartsDict;
    var i = -1;
    var continuousActions = actionBuffers.ContinuousActions;

    // 상체 관절 (chest, spine): 3축 회전 (6개)
    bpDict[chest].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], continuousActions[++i]);
    bpDict[spine].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], continuousActions[++i]);

    // 다리 관절 (thigh, shin, foot): 다양한 축 회전 (12개)
    bpDict[thighL].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);
    bpDict[thighR].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);
    bpDict[shinL].SetJointTargetRotation(continuousActions[++i], 0, 0);
    bpDict[shinR].SetJointTargetRotation(continuousActions[++i], 0, 0);
    bpDict[footR].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], continuousActions[++i]);
    bpDict[footL].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], continuousActions[++i]);

    // 팔 관절 (arm, forearm): 다양한 축 회전 (8개)
    bpDict[armL].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);
    bpDict[armR].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);
    bpDict[forearmL].SetJointTargetRotation(continuousActions[++i], 0, 0);
    bpDict[forearmR].SetJointTargetRotation(continuousActions[++i], 0, 0);
    bpDict[head].SetJointTargetRotation(continuousActions[++i], continuousActions[++i], 0);

    // 관절 강도 설정 (14개)
    bpDict[chest].SetJointStrength(continuousActions[++i]);
    bpDict[spine].SetJointStrength(continuousActions[++i]);
    bpDict[head].SetJointStrength(continuousActions[++i]);
    // ... 각 관절마다 강도 설정
}
```

**액션 공간**: 약 28차원 연속 액션
| 바디 파트 | 관절 회전 액션 | 강도 액션 |
|-----------|---------------|-----------|
| chest | 3 | 1 |
| spine | 3 | 1 |
| head | 2 | 1 |
| thighL/R | 2+2 | 1+1 |
| shinL/R | 1+1 | 1+1 |
| footL/R | 3+3 | 1+1 |
| armL/R | 2+2 | 1+1 |
| forearmL/R | 1+1 | 1+1 |
| **합계** | **24** | **~14** (일부 중복) |

#### GetMatchingVelocityReward() - 속도 일치 보상
```csharp
public float GetMatchingVelocityReward(Vector3 velocityGoal, Vector3 actualVelocity)
{
    var velDeltaMagnitude = Mathf.Clamp(
        Vector3.Distance(actualVelocity, velocityGoal), 0, MTargetWalkingSpeed);
    return Mathf.Pow(1 - Mathf.Pow(velDeltaMagnitude / MTargetWalkingSpeed, 2), 2);
}
```

#### FixedUpdate() - 보상 계산 (Crawler와 동일한 패턴)
```csharp
void FixedUpdate()
{
    UpdateOrientationObjects();

    var matchSpeedReward = GetMatchingVelocityReward(cubeForward * MTargetWalkingSpeed, GetAvgVelocity());

    // 머리 방향 기준 정렬 보상 (Crawler는 body 기준과 차이점)
    var headForward = head.forward;
    headForward.y = 0;
    var lookAtTargetReward = (Vector3.Dot(cubeForward, headForward) + 1) * .5F;

    AddReward(matchSpeedReward * lookAtTargetReward);
}
```

- Crawler와의 차이: **head.forward** 기준 방향 정렬 (body 대신)
- NaN 체크 포함 (디버깅용)

---

## 3. Crawler vs Walker 비교

| 특징 | Crawler | Walker |
|------|---------|--------|
| **보행 방식** | 4족 (거미형) | 2족 (인간형) |
| **바디 파트** | 8개 | 15개 |
| **액션 차원** | 20 | 약 28 |
| **관찰 차원** | ~20 | ~60-70 |
| **최대 속도** | 15 | 10 |
| **방향 기준** | body.forward | head.forward |
| **학습 난이도** | 중간 | 높음 |

---

## 4. 학습 실행

### 4.1 학습 명령어
```bash
mlagents-learn config/ppo/Walker.yaml --run-id=WalkerTest1
```

### 4.2 학습 설정
```yaml
behaviors:
  Walker:
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
      hidden_units: 512
      num_layers: 3
    reward_signals:
      extrinsic:
        gamma: 0.995
        strength: 1.0
    max_steps: 20000000
    time_horizon: 1000
    summary_freq: 30000
    keep_checkpoints: 5
```

---

## 5. 실습 과제

### 과제 1: 보행 속도 랜덤화
- `randomizeWalkSpeedEachEpisode = true`로 설정하고 학습
- 특정 속도만 학습 vs 다양한 속도 학습의 일반화 성능 비교

### 과제 2: 관절 강도 제한
- `SetJointStrength()`에 전달되는 값을 0.5로 제한하여 약한 보행 학습
- 강한 보행 vs 약한 보행의 에너지 효율성 비교

### 과제 3: Crawler와 Walker 비교
- 동일한 하이퍼파라미터로 Crawler와 Walker를 각각 학습
- 4족과 2족 보행의 학습 난이도와 안정성 비교 분석

### 과제 4: 넘어짐 감지 추가
- 에이전트가 넘어졌을 때(hips 높이가 일정 이하) 에피소드를 종료
- 넘어짐 패널티(-1)를 추가하여 안정적인 보행 유도

### 과제 5: 장애물 추가
- Walker 환경에 작은 장애물(경사로, 계단)을 추가
- 다양한 지형에서의 보행 학습

---

## 6. 파일 구조

```
Walker/
├── Scenes/
│   └── Walker.unity
├── Scripts/
│   └── WalkerAgent.cs             # 메인 에이전트
├── Prefabs/
│   ├── Platforms/Platform.prefab
│   └── Ragdoll/WalkerRagdoll.prefab
├── Materials/
│   └── WalkerCourt.mat
├── TFModels/
│   └── Walker.onnx
└── Demos/
    └── ExpertWalker.demo
```

---

## 7. 핵심 포인트

- **2족 보행**이라는 고난이도 RL 문제
- Crawler보다 더 많은 바디 파트(15개)와 액션(28차원)
- 머리 방향(head.forward)을 기준으로 한 방향 정렬
- NaN 체크를 통한 안정적인 학습 보장
- OrientationCube를 통한 일반화 성능 향상
- 복잡한 물리 시뮬레이션에서의 안정적인 보행 패턴 학습
- 다양한 속도에서도 작동하는 일반화된 보행 학습
- JointDriveController를 통한 관절 물리의 추상화
