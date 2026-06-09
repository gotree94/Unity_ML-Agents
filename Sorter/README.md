# Sorter 예제 가이드

## 1. 개요

Sorter는 숫자 타일을 오름차순으로 정렬하는 작업을 학습하는 환경입니다.
버퍼 센서(BufferSensorComponent)를 사용하여 가변 개수의 타일을 관찰하고,
올바른 순서로 타일을 터치해야 보상을 받습니다.

**목표**: 주어진 숫자 타일을 오름차순(1, 2, 3, ...)으로 순서대로 터치하기

### 학습 환경 구조

```
          [Agent]
            ↓ 이동
  ┌─────────────────────┐
  │   [3]  [7]  [1]     │  ← 무작위로 배치된 숫자 타일
  │        [5]          │
  │   [2]  [9]  [4]     │
  └─────────────────────┘
  올바른 순서: 1 → 2 → 3 → 4 → 5 → 7 → 9
```

---

## 2. 코드 분석

### 2.1 SorterAgent.cs

숫자 타일을 정렬하는 에이전트입니다.

```csharp
public class SorterAgent : Agent
{
    [Range(1, 20)]
    public int DefaultMaxNumTiles;
    private const int k_HighestTileValue = 20;
    int m_NumberOfTilesToSpawn;
    int m_MaxNumberOfTiles;
    Rigidbody m_AgentRb;

    BufferSensorComponent m_BufferSensor;  // 가변 개수 타일 관찰

    public List<NumberTile> NumberTilesList = new List<NumberTile>();
    private List<NumberTile> CurrentlyVisibleTilesList = new List<NumberTile>();
    private List<Transform> AlreadyTouchedList = new List<Transform>();
    private int m_NextExpectedTileIndex;
}
```

#### BufferSensorComponent 사용

Sorter의 핵심 특징은 **가변 개수의 타일**을 관찰하기 위해
`BufferSensorComponent`를 사용한다는 점입니다. 기존 `VectorSensor`는
고정된 차원만 가능하지만, BufferSensor는 에피소드마다 다른 개수의
관찰을 처리할 수 있습니다.

#### CollectObservations() - 고정 + 가변 관찰
```csharp
public override void CollectObservations(VectorSensor sensor)
{
    // 고정 관찰: 에이전트 위치 및 방향
    sensor.AddObservation((transform.position.x - m_Area.transform.position.x) / 20f);
    sensor.AddObservation((transform.position.z - m_Area.transform.position.z) / 20f);
    sensor.AddObservation(transform.forward.x);
    sensor.AddObservation(transform.forward.z);

    // 가변 관찰: BufferSensor로 각 타일 관찰
    foreach (var item in CurrentlyVisibleTilesList)
    {
        // 각 타일당 23차원 관찰
        float[] listObservation = new float[k_HighestTileValue + 3];
        listObservation[item.NumberValue] = 1.0f;                     // 원-핫 인코딩 (1~20)
        var tileTransform = item.transform.GetChild(1);
        listObservation[k_HighestTileValue] = (tileTransform.position.x - transform.position.x) / 20f;
        listObservation[k_HighestTileValue + 1] = (tileTransform.position.z - transform.position.z) / 20f;
        listObservation[k_HighestTileValue + 2] = item.IsVisited ? 1.0f : 0.0f;

        m_BufferSensor.AppendObservation(listObservation);
    }
}
```

**관찰 구조**:
| 항목 | 차원 | 설명 |
|------|------|------|
| 에이전트 위치 X | 1 | 영역 기준 상대 X 좌표 |
| 에이전트 위치 Z | 1 | 영역 기준 상대 Z 좌표 |
| 전방 방향 X | 1 | transform.forward.x |
| 전방 방향 Z | 1 | transform.forward.z |
| **각 타일** | **23** | (타일마다 BufferSensor에 추가) |

**타일별 관찰 (23차원)**:
| 인덱스 | 내용 |
|--------|------|
| 0~19 | 숫자 값 원-핫 인코딩 (1~20 중 해당 값만 1) |
| 20 | 타일 X 위치 (에이전트 기준) |
| 21 | 타일 Z 위치 (에이전트 기준) |
| 22 | 방문 여부 (0 또는 1) |

#### OnEpisodeBegin() - 에피소드 초기화
```csharp
public override void OnEpisodeBegin()
{
    m_MaxNumberOfTiles = (int)m_ResetParams.GetWithDefault("num_tiles", DefaultMaxNumTiles);
    m_NumberOfTilesToSpawn = Random.Range(1, m_MaxNumberOfTiles + 1);
    SelectTilesToShow();     // 표시할 타일 선택
    SetTilePositions();      // 타일 위치 설정

    transform.position = m_StartingPos;
    m_AgentRb.linearVelocity = Vector3.zero;
}
```

#### SelectTilesToShow() - 타일 선택 및 정렬
```csharp
void SelectTilesToShow()
{
    CurrentlyVisibleTilesList.Clear();
    AlreadyTouchedList.Clear();

    int numLeft = m_NumberOfTilesToSpawn;
    while (numLeft > 0)
    {
        int rndInt = Random.Range(0, k_HighestTileValue);
        var tmp = NumberTilesList[rndInt];
        if (!CurrentlyVisibleTilesList.Contains(tmp))
        {
            CurrentlyVisibleTilesList.Add(tmp);
            numLeft--;
        }
    }

    // 오름차순 정렬 (터치해야 할 순서)
    CurrentlyVisibleTilesList.Sort((x, y) => x.NumberValue.CompareTo(y.NumberValue));
    m_NextExpectedTileIndex = 0;
}
```

- 20개의 사용 가능한 타일 중 `m_NumberOfTilesToSpawn`개를 무작위 선택
- 선택된 타일을 숫자값 기준 **오름차순 정렬**
- `m_NextExpectedTileIndex`: 다음에 터치해야 할 타일의 인덱스

#### SetTilePositions() - 타일 배치
```csharp
void SetTilePositions()
{
    m_UsedPositionsList.Clear();
    foreach (var item in NumberTilesList)
    {
        item.ResetTile();
        item.gameObject.SetActive(false);
    }

    foreach (var item in CurrentlyVisibleTilesList)
    {
        // 사용되지 않은 위치 인덱스 선택 (0~19)
        bool posChosen = false;
        int rndPosIndx = 0;
        while (!posChosen)
        {
            rndPosIndx = Random.Range(0, k_HighestTileValue);
            if (!m_UsedPositionsList.Contains(rndPosIndx))
            {
                m_UsedPositionsList.Add(rndPosIndx);
                posChosen = true;
            }
        }
        // 방사형 배치 (360 / 20 = 18도 간격)
        item.transform.localRotation = Quaternion.Euler(0, rndPosIndx * (360f / k_HighestTileValue), 0);
        item.gameObject.SetActive(true);
    }
}
```

- 타일은 에이전트를 중심으로 방사형 배치 (18도 간격)
- 각 타일의 위치는 랜덤하게 지정 (중복 없음)

#### OnCollisionEnter() - 터치 검증
```csharp
private void OnCollisionEnter(Collision col)
{
    if (!col.gameObject.CompareTag("tile")) return;
    if (AlreadyTouchedList.Contains(col.transform)) return;

    if (col.transform.parent != CurrentlyVisibleTilesList[m_NextExpectedTileIndex].transform)
    {
        // 잘못된 순서 → 실패
        AddReward(-1);
        EndEpisode();
    }
    else
    {
        // 올바른 순서 → 성공
        AddReward(1);
        var tile = col.gameObject.GetComponentInParent<NumberTile>();
        tile.VisitTile();
        m_NextExpectedTileIndex++;

        AlreadyTouchedList.Add(col.transform);

        // 모든 타일 완료
        if (m_NextExpectedTileIndex == m_NumberOfTilesToSpawn)
            EndEpisode();
    }
}
```

- 현재 예상된 타일(`m_NextExpectedTileIndex`)과 일치하면 +1, 불일치하면 -1 후 종료
- 이미 터치한 타일은 중복 처리되지 않음

#### OnActionReceived() - 매 스텝 패널티
```csharp
public override void OnActionReceived(ActionBuffers actionBuffers)
{
    MoveAgent(actionBuffers.DiscreteActions);
    AddReward(-1f / MaxStep);  // 시간 패널티 (빨리 끝내도록 유도)
}
```

- 매 스텝 `-1/MaxStep`의 작은 패널티 → 효율적인 경로 학습 유도

#### MoveAgent() - 이산 액션
```csharp
public void MoveAgent(ActionSegment<int> act)
{
    var forwardAxis = act[0];  // 0=None, 1=전진, 2=후진
    var rightAxis = act[1];    // 0=None, 1=우측, 2=좌측
    var rotateAxis = act[2];   // 0=None, 1=좌회전, 2=우회전

    switch (forwardAxis) {
        case 1: dirToGo = transform.forward * 1f; break;
        case 2: dirToGo = transform.forward * -1f; break;
    }
    switch (rightAxis) {
        case 1: dirToGo = transform.right * 1f; break;
        case 2: dirToGo = transform.right * -1f; break;
    }
    switch (rotateAxis) {
        case 1: rotateDir = transform.up * -1f; break;
        case 2: rotateDir = transform.up * 1f; break;
    }

    transform.Rotate(rotateDir, Time.deltaTime * 200f);
    m_AgentRb.AddForce(dirToGo * 2, ForceMode.VelocityChange);
}
```

**액션 공간**: 3차원 이산 액션 (각 3개 값)
| 차원 | 0 | 1 | 2 |
|------|---|---|---|
| forward (act[0]) | None | 전진 | 후진 |
| right (act[1]) | None | 오른쪽 | 왼쪽 |
| rotate (act[2]) | None | 좌회전 | 우회전 |

### 2.2 NumberTile.cs

각 숫자 타일의 상태를 관리합니다.

```csharp
public class NumberTile : MonoBehaviour
{
    public int NumberValue;              // 타일의 숫자값
    public Material DefaultMaterial;
    public Material SuccessMaterial;

    private bool m_Visited;              // 터치 완료 여부
    private MeshRenderer m_Renderer;

    public void VisitTile()
    {
        m_Renderer.sharedMaterial = SuccessMaterial;  // 성공 시 색상 변경
        m_Visited = true;
    }

    public void ResetTile()
    {
        m_Renderer.sharedMaterial = DefaultMaterial;
        m_Visited = false;
    }
}
```

---

## 3. 관찰-액션-보상 구조

| 항목 | 내용 |
|------|------|
| **관찰** | 고정 4차원 (위치/방향) + BufferSensor (타일당 23차원, 가변 개수) |
| **액션** | 3차원 이산 (전진/후진, 좌우, 회전) |
| **보상** | 올바른 타일 터치 +1, 잘못된 타일 -1, 매 스텝 -1/MaxStep |
| **종료 조건** | 잘못된 타일 터치 or 모든 타일 완료 or MaxStep |

---

## 4. 학습 실행

### 4.1 학습 명령어
```bash
mlagents-learn config/ppo/Sorter.yaml --run-id=SorterTest1
```

### 4.2 학습 설정
```yaml
behaviors:
  Sorter:
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
    max_steps: 10000000
    time_horizon: 64
    summary_freq: 10000
    keep_checkpoints: 5
```

---

## 5. 실습 과제

### 과제 1: 타일 개수 커리큘럼
- `num_tiles` 파라미터를 3에서 시작하여 점진적 증가
- 적은 타일 → 많은 타일 순서로 난이도 증가

### 과제 2: 내림차순 정렬
- 오름차순을 내림차순으로 변경하여 학습
- 정렬 방향이 학습 난이도에 미치는 영향

### 과제 3: BufferSensor 없이 학습
- 모든 타일을 고정된 최대 개수(20)의 VectorSensor로 관찰
- BufferSensor 사용의 효율성 비교

### 과제 4: 위치 기억력 테스트
- 타일을 처음에만 보여주고 뒤집은 후 정렬
- Working Memory 요소 추가

### 과제 5: 타일 위치 패턴 변경
- 방사형 배치 대신 격자형 배치로 변경
- 공간 탐색 전략의 차이 분석

---

## 6. 파일 구조

```
Sorter/
├── Scenes/
│   └── Sorter.unity
├── Scripts/
│   ├── SorterAgent.cs              # 메인 에이전트
│   └── NumberTile.cs               # 타일 상태 관리
└── TFModels/
    └── Sorter.onnx
```

---

## 7. 핵심 포인트

- **BufferSensorComponent**를 사용한 가변 개수 관찰 처리
- 숫자 타일을 **오름차순**으로 순서대로 터치하는 작업
- 각 타일은 23차원 관찰 (원-핫 인코딩 + 위치 + 방문 여부)
- 방사형 배치로 타일 위치 랜덤화
- **순서 학습**: 예상된 순서와 일치하는 타일만 터치해야 보상
- 매 스텝 시간 패널티로 효율적인 경로 학습 유도
- Curriculum Learning 지원 (`num_tiles` 파라미터)
- 20개 타일 중 일부만 선택하여 다양한 조합 생성
- 올바른 순서 보상(+1) / 잘못된 순서 패널티(-1, 종료)
