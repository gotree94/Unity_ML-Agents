# Pyramids 예제 가이드

## 1. 개요

Pyramids는 에이전트가 스위치를 눌러 피라미드를 생성하고, 그 피라미드를 밀어서 목표 지점에 도달해야 하는 환경입니다.
에이전트는 먼저 스위치를 찾아 활성화시킨 후, 생성된 피라미드를 밀어내야 합니다.

**목표**: 스위치 활성화 → 피라미드 생성 → 피라미드를 밀어 목표 도달

### 학습 환경 구조

```
  [Switch] → 누르면 → [Pyramid] 생성
                          ↓
             에이전트가 피라미드를 밀어서
                          ↓
                    [Goal] 도달
```

---

## 2. 코드 분석

### 2.1 PyramidAgent.cs

스위치를 찾고 피라미드를 미는 에이전트입니다.

```csharp
public class PyramidAgent : Agent
{
    public GameObject area;
    PyramidArea m_MyArea;
    Rigidbody m_AgentRb;
    PyramidSwitch m_SwitchLogic;
    public GameObject areaSwitch;
    public bool useVectorObs;
}
```

#### Initialize() - 초기화
```csharp
public override void Initialize()
{
    m_AgentRb = GetComponent<Rigidbody>();
    m_MyArea = area.GetComponent<PyramidArea>();
    m_SwitchLogic = areaSwitch.GetComponent<PyramidSwitch>();
}
```

#### CollectObservations() - 관찰 수집
```csharp
public override void CollectObservations(VectorSensor sensor)
{
    if (useVectorObs)
    {
        sensor.AddObservation(m_SwitchLogic.GetState());  // 스위치 상태 (bool)
        sensor.AddObservation(transform.InverseTransformDirection(m_AgentRb.linearVelocity));  // 속도
    }
}
```

**관찰 공간**: 3차원 벡터 (useVectorObs=true)
| 인덱스 | 내용 |
|--------|------|
| 0 | 스위치 상태 (0=꺼짐, 1=켜짐) |
| 1-2 | 로컬 기준 선속도 (x, z) |

#### MoveAgent() - 액션 처리
```csharp
public void MoveAgent(ActionSegment<int> act)
{
    var dirToGo = Vector3.zero;
    var rotateDir = Vector3.zero;
    var action = act[0];

    switch (action)
    {
        case 1: dirToGo = transform.forward * 1f; break;     // 전진
        case 2: dirToGo = transform.forward * -1f; break;    // 후진
        case 3: rotateDir = transform.up * 1f; break;        // 우회전
        case 4: rotateDir = transform.up * -1f; break;       // 좌회전
    }
    transform.Rotate(rotateDir, Time.deltaTime * 200f);
    m_AgentRb.AddForce(dirToGo * 2f, ForceMode.VelocityChange);
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
    AddReward(-1f / MaxStep);  // 스텝 패널티
    MoveAgent(actionBuffers.DiscreteActions);
}
```

#### OnCollisionEnter() - 목표 달성
```csharp
void OnCollisionEnter(Collision collision)
{
    if (collision.gameObject.CompareTag("goal"))
    {
        SetReward(2f);      // 목표 도달: +2 보상
        EndEpisode();
    }
}
```

#### OnEpisodeBegin() - 에피소드 시작
```csharp
public override void OnEpisodeBegin()
{
    // 0~8 사이의 랜덤 순서 생성
    var enumerable = Enumerable.Range(0, 9).OrderBy(x => Guid.NewGuid()).Take(9);
    var items = enumerable.ToArray();

    m_MyArea.CleanPyramidArea();  // 기존 피라미드 제거

    m_AgentRb.linearVelocity = Vector3.zero;
    m_MyArea.PlaceObject(gameObject, items[0]);  // 에이전트 위치
    transform.rotation = Quaternion.Euler(new Vector3(0f, Random.Range(0, 360)));

    m_SwitchLogic.ResetSwitch(items[1], items[2]);  // 스위치 위치와 피라미드 스폰 위치
    
    // 6개의 돌 피라미드 생성 (일부는 장애물)
    m_MyArea.CreateStonePyramid(1, items[3]);
    m_MyArea.CreateStonePyramid(1, items[4]);
    m_MyArea.CreateStonePyramid(1, items[5]);
    m_MyArea.CreateStonePyramid(1, items[6]);
    m_MyArea.CreateStonePyramid(1, items[7]);
    m_MyArea.CreateStonePyramid(1, items[8]);
}
```

- 9개의 스폰 영역 중 1곳에 에이전트, 2곳에 스위치와 피라미드, 6곳에 돌 장애물 배치
- 각 에피소드마다 모든 위치가 랜덤화되어 일반화 학습 촉진

### 2.2 PyramidSwitch.cs

스위치 역할을 하는 오브젝트입니다.

```csharp
public class PyramidSwitch : MonoBehaviour
{
    public Material onMaterial;
    public Material offMaterial;
    public GameObject myButton;
    bool m_State;
    int m_PyramidIndex;       // 피라미드가 생성될 스폰 영역 인덱스
}
```

```csharp
void OnCollisionEnter(Collision other)
{
    if (other.gameObject.CompareTag("agent") && m_State == false)
    {
        myButton.GetComponent<Renderer>().material = onMaterial;  // 시각적 변경
        m_State = true;          // 스위치 켜짐
        m_AreaComponent.CreatePyramid(1, m_PyramidIndex);  // 피라미드 생성
        tag = "switchOn";
    }
}
```

- 에이전트가 스위치에 충돌하면 상태 변경 및 피라미드 생성
- 스위치 재질이 offMaterial → onMaterial로 변경
- 피라미드는 스위치와 다른 랜덤 위치에 생성됨

```csharp
public bool GetState()
{
    return m_State;  // 관찰을 위한 상태 반환
}
```

### 2.3 PyramidArea.cs

환경 내 피라미드와 오브젝트를 관리합니다.

```csharp
public class PyramidArea : Area
{
    public GameObject pyramid;
    public GameObject stonePyramid;
    public GameObject[] spawnAreas;
    public int numPyra;
    public float range;
}
```

```csharp
public void PlaceObject(GameObject objectToPlace, int spawnAreaIndex)
{
    var spawnTransform = spawnAreas[spawnAreaIndex].transform;
    var xRange = spawnTransform.localScale.x / 2.1f;
    var zRange = spawnTransform.localScale.z / 2.1f;

    objectToPlace.transform.position = new Vector3(
        Random.Range(-xRange, xRange), 2f, Random.Range(-zRange, zRange))
        + spawnTransform.position;
}

public void CleanPyramidArea()
{
    // "pyramid" 태그를 가진 모든 자식 오브젝트 제거
    foreach (Transform child in transform)
        if (child.CompareTag("pyramid"))
            Destroy(child.gameObject);
}
```

- `Area` 기본 클래스를 상속받아 구현
- `spawnAreas` 배열로 여러 스폰 영역 관리
- `PlaceObject()`로 랜덤 위치에 오브젝트 배치

---

## 3. 관찰-액션-보상 구조

| 항목 | 내용 |
|------|------|
| **관찰** | 3차원 (스위치 상태, 속도 x, 속도 z) |
| **액션** | 이산 5개 (전진/후진/좌회전/우회전/정지) |
| **보상** | 매 스텝 -1/MaxStep, 목표 도달 +2 |
| **종료 조건** | "goal" 태그와 충돌 시 |
| **핵심 과제** | **2단계 작업**: 스위치 → 피라미드 → 목표 |

---

## 4. 학습 실행

### 4.1 학습 명령어
```bash
mlagents-learn config/ppo/Pyramids.yaml --run-id=PyramidsTest1
```

### 4.2 학습 설정
```yaml
behaviors:
  Pyramids:
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
    max_steps: 2000000
    time_horizon: 64
    summary_freq: 30000
    keep_checkpoints: 5
```

---

## 5. 실습 과제

### 과제 1: 계층적 보상 구조
- 스위치를 눌렀을 때 중간 보상(+0.5)을 추가하여 학습 속도 개선
- 2단계 작업에서 중간 보상의 효과 분석

```csharp
// PyramidSwitch.cs에서
if (other.gameObject.CompareTag("agent") && m_State == false)
{
    m_State = true;
    // 에이전트에게 중간 보상 -- 추가 필요
    m_AreaComponent.CreatePyramid(1, m_PyramidIndex);
}
```

### 과제 2: 피라미드 개수 변경
- `numPyra` 값을 늘려 더 많은 장애물 생성
- 장애물이 많을수록 학습 난이도 변화 관찰

### 과제 3: 스폰 영역 확장
- `spawnAreas` 배열에 영역을 더 추가하여 더 넓은 환경에서 학습
- 9개 → 16개 영역으로 확장

### 과제 4: 스위치 두 번 누르기
- 스위치를 두 번 눌러야 피라미드가 생성되도록 변경
- `m_State`를 int 카운터로 변경하여 2회 충돌 필요

### 과제 5: Visual Observation 학습
- `useVectorObs=false`로 설정하고 시각 관찰만으로 학습
- 벡터 관찰과 시각 관찰의 학습 효율 비교

---

## 6. 파일 구조

```
Pyramids/
├── Scenes/
│   └── Pyramids.unity
├── Scripts/
│   ├── PyramidAgent.cs       # 메인 에이전트
│   ├── PyramidArea.cs        # 환경 생성/관리
│   └── PyramidSwitch.cs      # 스위치 로직
├── Prefabs/
│   ├── AreaPB.prefab
│   ├── BrickPyramid.prefab
│   └── StonePyramid.prefab
├── Meshes/
│   ├── CruciformWall.fbx
│   ├── SideWalls.fbx
│   ├── SpawnAreas.fbx
│   ├── Switch.fbx
│   └── Walls.fbx
├── TFModels/
│   └── Pyramids.onnx
└── Demos/
    └── ExpertPyramid.demo
```

---

## 7. 핵심 포인트

- **2단계 계층적 작업**: 스위치 활성화 → 피라미드 생성 → 목표 도달
- 스위치 상태 관찰을 통한 환경 상태 인식
- `Guid` 기반 랜덤 순서 생성으로 매 에피소드 고유한 배치
- `Area` 기본 클래스 상속 구조
- 스위치의 시각적 피드백 (재질 변경)
- Pyramid와 StonePyramid 두 가지 오브젝트 타입 (목표/장애물)
- 9개 스폰 영역의 완전 랜덤 배치로 일반화 학습 강화
- 단순 관찰로 복잡한 작업을 해결해야 하는 과제
