# GridWorld 예제 가이드

## 1. 개요

GridWorld는 격자(Grid) 위에서 에이전트가 목표 지점을 찾아 이동하는 환경입니다.
에이전트는 매 에피소드마다 목표(초록색 + 또는 빨간색 X)를 할당받고, 올바른 목표에 도달해야 보상을 받습니다.
Action Masking과 다양한 격자 크기를 지원합니다.

**목표**: 할당된 목표(초록색+ / 빨간색X)를 찾아 도달하기

### 학습 환경 구조

```
+---+---+---+---+---+
|   |   | X |   |   |    X: 빨간색 목표 (RedEx)
+---+---+---+---+---+
|   |   |   |   |   |
+---+---+---+---+---+
|   | A |   |   |   |    A: 에이전트 (시작 위치)
+---+---+---+---+---+
|   |   |   |   |   |
+---+---+---+---+---+
|   |   | + |   |   |    +: 초록색 목표 (GreenPlus)
+---+---+---+---+---+
```

---

## 2. 코드 분석

### 2.1 GridAgent.cs

격자 위를 이동하는 에이전트입니다.

```csharp
public class GridAgent : Agent
{
    public GridArea area;
    public float timeBetweenDecisionsAtInference;
    public Camera renderCamera;      // RenderTexture 관찰용 카메라
    public bool maskActions = true;  // Action Masking 사용 여부

    public enum GridGoal { GreenPlus, RedEx }

    public GameObject GreenBottom;
    public GameObject RedBottom;
    GridGoal m_CurrentGoal;

    const int k_NoAction = 0;   // 정지
    const int k_Up = 1;         // 위
    const int k_Down = 2;       // 아래
    const int k_Left = 3;       // 왼쪽
    const int k_Right = 4;      // 오른쪽
}
```

#### CollectObservations() - 관찰 수집
```csharp
public override void CollectObservations(VectorSensor sensor)
{
    Array values = Enum.GetValues(typeof(GridGoal));
    if (m_GoalSensor is object)
    {
        int goalNum = (int)CurrentGoal;
        m_GoalSensor.GetSensor().AddOneHotObservation(goalNum, values.Length);
    }
}
```

- 목표 종류를 One-Hot 인코딩으로 관찰에 추가
- 2차원 (GreenPlus=0, RedEx=1)

#### WriteDiscreteActionMask() - Action Masking
```csharp
public override void WriteDiscreteActionMask(IDiscreteActionMask actionMask)
{
    if (maskActions)
    {
        var positionX = (int)transform.localPosition.x;
        var positionZ = (int)transform.localPosition.z;
        var maxPosition = (int)m_ResetParams.GetWithDefault("gridSize", 5f) - 1;

        // 왼쪽 벽에 닿았으면 Left 액션 비활성화
        if (positionX == 0) actionMask.SetActionEnabled(0, k_Left, false);
        // 오른쪽 벽에 닿았으면 Right 액션 비활성화
        if (positionX == maxPosition) actionMask.SetActionEnabled(0, k_Right, false);
        // 아래쪽 벽에 닿았으면 Down 액션 비활성화
        if (positionZ == 0) actionMask.SetActionEnabled(0, k_Down, false);
        // 위쪽 벽에 닿았으면 Up 액션 비활성화
        if (positionZ == maxPosition) actionMask.SetActionEnabled(0, k_Up, false);
    }
}
```

- 벽에 닿은 방향의 이동 액션을 마스킹하여 불필요한 액션 방지
- 학습 효율을 높이는 중요한 기법

#### OnActionReceived() - 액션 처리
```csharp
public override void OnActionReceived(ActionBuffers actionBuffers)
{
    AddReward(-0.01f);  // 스텝 당 패널티
    var action = actionBuffers.DiscreteActions[0];

    var targetPos = transform.position;
    switch (action)
    {
        case k_Right: targetPos = transform.position + new Vector3(1f, 0, 0f); break;
        case k_Left:  targetPos = transform.position + new Vector3(-1f, 0, 0f); break;
        case k_Up:    targetPos = transform.position + new Vector3(0f, 0, 1f); break;
        case k_Down:  targetPos = transform.position + new Vector3(0f, 0, -1f); break;
    }

    // 충돌 검사 (벽 통과 방지)
    var hit = Physics.OverlapBox(targetPos, new Vector3(0.3f, 0.3f, 0.3f));
    if (hit.Where(col => col.gameObject.CompareTag("wall")).ToArray().Length == 0)
    {
        transform.position = targetPos;

        if (hit.Where(col => col.gameObject.CompareTag("plus")).ToArray().Length == 1)
        {
            ProvideReward(GridGoal.GreenPlus);
            EndEpisode();
        }
        else if (hit.Where(col => col.gameObject.CompareTag("ex")).ToArray().Length == 1)
        {
            ProvideReward(GridGoal.RedEx);
            EndEpisode();
        }
    }
}
```

- Physics.OverlapBox로 목표 도달 및 벽 충돌 검사
- 벽이 있으면 이동하지 않음 (Action Masking과 이중 안전장치)

#### ProvideReward() - 보상 지급
```csharp
private void ProvideReward(GridGoal hitObject)
{
    if (CurrentGoal == hitObject)
        SetReward(1f);     // 올바른 목표: +1
    else
        SetReward(-1f);    // 잘못된 목표: -1
}
```

#### OnEpisodeBegin() - 에피소드 시작
```csharp
public override void OnEpisodeBegin()
{
    area.AreaReset();
    Array values = Enum.GetValues(typeof(GridGoal));
    if (m_GoalSensor is object)
        CurrentGoal = (GridGoal)values.GetValue(UnityEngine.Random.Range(0, values.Length));
    else
        CurrentGoal = GridGoal.GreenPlus;
}
```

#### WaitTimeInference() - 의사결정 타이밍
```csharp
void WaitTimeInference()
{
    if (renderCamera != null && SystemInfo.graphicsDeviceType != GraphicsDeviceType.Null)
        renderCamera.Render();          // RenderTexture 업데이트

    if (Academy.Instance.IsCommunicatorOn)
        RequestDecision();
    else
    {
        if (m_TimeSinceDecision >= timeBetweenDecisionsAtInference)
        {
            m_TimeSinceDecision = 0f;
            RequestDecision();
        }
        else
            m_TimeSinceDecision += Time.fixedDeltaTime;
    }
}
```

### 2.2 GridArea.cs

격자 환경을 생성하고 관리합니다.

```csharp
public class GridArea : MonoBehaviour
{
    public GameObject GreenPlusPrefab;
    public GameObject RedExPrefab;
    public int numberOfPlus = 1;
    public int numberOfEx = 1;
    Camera m_AgentCam;
}
```

**SetEnvironment()** - 격자 크기에 따라 환경 크기 조절
```csharp
void SetEnvironment()
{
    var gridSize = (int)m_ResetParams.GetWithDefault("gridSize", 5f);
    m_Plane.transform.localScale = new Vector3(gridSize / 10.0f, 1f, gridSize / 10.0f);
    m_AgentCam.orthographicSize = (gridSize) / 2f;
    // 벽 위치도 gridSize에 맞게 조정...
}
```

**AreaReset()** - 에리어 리셋
```csharp
public void AreaReset()
{
    var gridSize = (int)m_ResetParams.GetWithDefault("gridSize", 5f);
    // 기존 오브젝트 제거
    foreach (var actor in actorObjs)
        DestroyImmediate(actor);

    SetEnvironment();
    actorObjs.Clear();

    // 에이전트와 목표들의 랜덤 위치 선정 (중복 없음)
    var numbers = new HashSet<int>();
    while (numbers.Count < players.Length + 1)
        numbers.Add(Random.Range(0, gridSize * gridSize));
    // ... 위치에 오브젝트 배치
}
```

### 2.3 GridSettings.cs

환경 설정 (카메라 위치 조정).

```csharp
public class GridSettings : MonoBehaviour
{
    public Camera MainCamera;

    public void Awake()
    {
        Academy.Instance.EnvironmentParameters.RegisterCallback("gridSize", f =>
        {
            MainCamera.transform.position = new Vector3(-(f - 1) / 2f, f * 1.25f, -(f - 1) / 2f);
            MainCamera.orthographicSize = (f + 5f) / 2f;
        });
    }
}
```

- `gridSize` 파라미터 변경 시 카메라 위치와 크기 자동 조정

---

## 3. 관찰-액션-보상 구조

| 항목 | 내용 |
|------|------|
| **관찰** | 목표 종류 One-Hot (2차원) + RenderTexture (선택사항) |
| **액션** | 이산 5개 (정지/위/아래/왼/오른쪽) |
| **보상** | 매 스텝 -0.01, 올바른 목표 +1.0, 잘못된 목표 -1.0 |
| **종료 조건** | 목표 도달 시 |
| **특징** | Action Masking 지원 (maskActions=true) |

---

## 4. 학습 실행

### 4.1 학습 설정 (config/ppo/GridWorld.yaml)

```yaml
behaviors:
  GridWorld:
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
    max_steps: 100000
    time_horizon: 64
    summary_freq: 5000
    keep_checkpoints: 5
```

### 4.2 학습 명령어

```bash
mlagents-learn config/ppo/GridWorld.yaml --run-id=GridWorldTest1
```

---

## 5. 실습 과제

### 과제 1: 격자 크기 변경
- `gridSize`를 5에서 7, 10으로 늘리면 학습이 어떻게 달라지는지 관찰하세요.
- 격자가 커질수록 필요한 학습 스텝 수가 어떻게 증가하는지 기록하세요.

**힌트**: 학습 명령어에 `--curriculum` 플래그를 사용하거나 `EnvironmentParameters`로 `gridSize` 전달.

### 과제 2: Action Masking 비교
- `maskActions=false`로 설정하고 학습하여 Action Masking의 효과를 측정하세요.
- Action Masking 유/무에 따른 학습 속도와 최종 성능을 비교하세요.

### 과제 3: 목표 개수 변경
- `numberOfPlus`와 `numberOfEx` 값을 2, 3으로 늘려보세요.
- 목표가 많아질수록 학습 난이도가 어떻게 변하는지 관찰하세요.

### 과제 4: 보상 구조 변경
- 올바른 목표 보상을 +1 대신 +5로, 잘못된 목표를 -1 대신 -5로 변경해보세요.
- 보상 크기가 학습 속도와 안정성에 미치는 영향을 분석하세요.

### 과제 5: Visual Observation 학습
- RenderTexture를 통한 시각 관찰로 학습해보세요.
- `renderCamera`를 활성화하고 Vector Observation 없이 학습.

**힌트**: 
1. GridAgent의 `m_GoalSensor`가 null이면 GridGoal.GreenPlus로 고정
2. `renderCamera`를 활성화하고 `GridWorldColab` 씬 참조

### 과제 6: Co-op 버전 실험
- `GridWorldColab.unity`에서 2명의 에이전트가 협력하여 목표를 찾도록 학습해보세요.
- `config/poca/GridWorld.yaml` 설정 사용.

---

## 6. 파일 구조

```
GridWorld/
├── Scenes/
│   ├── GridWorld.unity            # 싱글 에이전트
│   └── GridWorldColab.unity       # 협력(co-op) 버전
├── Scripts/
│   ├── GridAgent.cs               # 메인 에이전트
│   ├── GridArea.cs                # 격자 환경 생성
│   └── GridSettings.cs            # 환경 설정 (카메라)
├── Prefabs/
│   ├── Area.prefab
│   ├── AreaColab.prefab
│   ├── goal-ex.prefab             # 빨간색 X 목표
│   ├── goal-plus.prefab           # 초록색 + 목표
│   └── agentRenderTexture.renderTexture
├── TFModels/
│   ├── GridWorld.onnx
│   └── GridWorldColab.onnx
└── Demos/
    └── ExpertGridWorld.demo
```

---

## 7. 핵심 포인트

- 이산적 격자 환경에서의 전형적인 RL 문제
- **Action Masking**을 통한 학습 효율 향상 (불가능한 액션 차단)
- One-Hot 인코딩을 사용한 목표 정보 전달
- `EnvironmentParameters`를 통한 환경 난이도 동적 조절
- `HashSet`을 사용한 중복 없는 랜덤 위치 생성
- Co-op 학습을 위한 SimpleMultiAgentGroup 사용 (GridWorldColab)
- 카메라 위치 자동 조정으로 다양한 격자 크기 지원
