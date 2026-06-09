# DungeonEscape 예제 가이드

## 1. 개요

DungeonEscape는 여러 에이전트가 협력하여 던전을 탈출하는 협력형 멀티 에이전트 환경입니다.
에이전트들은 열쇠를 찾아 문을 열고, 드래곤을 피해 포탈로 탈출해야 합니다.
드래곤에게 잡히면 비석(Tombstone)이 세워지고 열쇠가 드롭됩니다.

**목표**: 모든 에이전트가 협력하여 던전을 탈출하기

### 학습 환경 구조

```
┌──────────────────────────────────────┐
│   [Key] ──→ [Locked Door] ←─── [Key]  │
│         ↙                    ↘         │
│  [Agent]                [Dragon]       │
│     ↓                    ↓             │
│  [Tombstone]     [Key Drop]           │
│     ↓                    ↓             │
│  [Portal] ←──────── [Escape]          │
└──────────────────────────────────────┘
```

---

## 2. 코드 분석

### 2.1 PushAgentEscape.cs

던전 탈출을 위한 메인 에이전트입니다.

```csharp
public class PushAgentEscape : Agent
{
    public GameObject MyKey;   // 내 키 오브젝트
    public bool IHaveAKey;     // 키 소유 여부
    private PushBlockSettings m_PushBlockSettings;
    private Rigidbody m_AgentRb;
    private DungeonEscapeEnvController m_GameController;
}
```

#### Initialize()
```csharp
public override void Initialize()
{
    m_GameController = GetComponentInParent<DungeonEscapeEnvController>();
    m_AgentRb = GetComponent<Rigidbody>();
    m_PushBlockSettings = FindFirstObjectByType<PushBlockSettings>();
    MyKey.SetActive(false);
    IHaveAKey = false;
}
```

#### OnEpisodeBegin()
```csharp
public override void OnEpisodeBegin()
{
    MyKey.SetActive(false);
    IHaveAKey = false;
}
```

#### CollectObservations() - 단순 관찰
```csharp
public override void CollectObservations(VectorSensor sensor)
{
    sensor.AddObservation(IHaveAKey);  // 키 소유 여부 (boolean)
}
```

매우 단순한 관찰 공간: **단 1차원** (키 보유 여부)

#### MoveAgent() - 이산 액션
```csharp
public void MoveAgent(ActionSegment<int> act)
{
    var dirToGo = Vector3.zero;
    var rotateDir = Vector3.zero;
    var action = act[0];

    switch (action)
    {
        case 1: dirToGo = transform.forward * 1f; break;         // 전진
        case 2: dirToGo = transform.forward * -1f; break;        // 후진
        case 3: rotateDir = transform.up * 1f; break;            // 우회전
        case 4: rotateDir = transform.up * -1f; break;           // 좌회전
        case 5: dirToGo = transform.right * -0.75f; break;       // 왼쪽 이동
        case 6: dirToGo = transform.right * 0.75f; break;        // 오른쪽 이동
    }
    transform.Rotate(rotateDir, Time.fixedDeltaTime * 200f);
    m_AgentRb.AddForce(dirToGo * m_PushBlockSettings.agentRunSpeed, ForceMode.VelocityChange);
}
```

**액션 공간**: 1차원 이산 (7개 값: 0=None, 1~6=방향)

#### OnCollisionEnter() - 충돌 처리
```csharp
void OnCollisionEnter(Collision col)
{
    if (col.transform.CompareTag("lock"))
    {
        if (IHaveAKey)
        {
            MyKey.SetActive(false);
            IHaveAKey = false;
            m_GameController.UnlockDoor();  // 문 열기 성공
        }
    }
    if (col.transform.CompareTag("dragon"))
    {
        m_GameController.KilledByBaddie(this, col);  // 드래곤에게 사망
        MyKey.SetActive(false);
        IHaveAKey = false;
    }
    if (col.transform.CompareTag("portal"))
    {
        m_GameController.TouchedHazard(this);  // 포탈 접촉 (제거됨)
    }
}
```

#### OnTriggerEnter() - 키 획득
```csharp
void OnTriggerEnter(Collider col)
{
    if (col.transform.CompareTag("key") && col.transform.parent == transform.parent)
    {
        print("Picked up key");
        MyKey.SetActive(true);
        IHaveAKey = true;
        col.gameObject.SetActive(false);  // 키 수집
    }
}
```

### 2.2 DungeonEscapeEnvController.cs

던전 환경의 전체 상태를 관리합니다.

```csharp
public class DungeonEscapeEnvController : MonoBehaviour
{
    [System.Serializable]
    public class PlayerInfo { ... }

    [System.Serializable]
    public class DragonInfo
    {
        public SimpleNPC Agent;
        public Transform T;
        public bool IsDead;
    }

    public int MaxEnvironmentSteps = 25000;
    public GameObject ground;
    public List<PlayerInfo> AgentsList;
    public List<DragonInfo> DragonsList;
    public bool UseRandomAgentRotation = true;
    public bool UseRandomAgentPosition = true;
    public GameObject Key;
    public GameObject Tombstone;

    private SimpleMultiAgentGroup m_AgentGroup;
    private int m_NumberOfRemainingPlayers;
}
```

#### Start() - 다중 에이전트 그룹 등록
```csharp
void Start()
{
    // Initialize TeamManager
    m_AgentGroup = new SimpleMultiAgentGroup();
    foreach (var item in AgentsList)
    {
        item.StartingPos = item.Agent.transform.position;
        item.StartingRot = item.Agent.transform.rotation;
        item.Rb = item.Agent.GetComponent<Rigidbody>();
        m_AgentGroup.RegisterAgent(item.Agent);  // 협력 그룹 등록
    }
    ResetScene();
}
```

#### TouchedHazard() - 포탈 접촉
```csharp
public void TouchedHazard(PushAgentEscape agent)
{
    m_NumberOfRemainingPlayers--;
    if (m_NumberOfRemainingPlayers == 0 || agent.IHaveAKey)
    {
        m_AgentGroup.EndGroupEpisode();  // 모두 탈출 or 키 소지자가 탈출
        ResetScene();
    }
    else
    {
        agent.gameObject.SetActive(false);  // 해당 에이전트만 비활성화
    }
}
```

- 모든 에이전트가 포탈에 도착하거나, 키를 가진 에이전트가 포탈에 도착하면 종료
- 일부만 포탈에 도착해도 진행 가능 (남은 에이전트가 계속 플레이)

#### UnlockDoor() - 문 열기 성공
```csharp
public void UnlockDoor()
{
    m_AgentGroup.AddGroupReward(1f);  // 협력 보상
    StartCoroutine(GoalScoredSwapGroundMaterial(m_PushBlockSettings.goalScoredMaterial, 0.5f));
    m_AgentGroup.EndGroupEpisode();
    ResetScene();
}
```

#### KilledByBaddie() - 드래곤에게 사망
```csharp
public void KilledByBaddie(PushAgentEscape agent, Collision baddieCol)
{
    baddieCol.gameObject.SetActive(false);         // 드래곤 제거
    m_NumberOfRemainingPlayers--;
    agent.gameObject.SetActive(false);             // 에이전트 제거
    Tombstone.SetActive(true);                     // 비석 생성
    // 드래곤 위치에 키 드롭
    Key.transform.SetPositionAndRotation(baddieCol.collider.transform.position, ...);
    Key.SetActive(true);
}
```

- 드래곤이 에이전트를 잡으면 드래곤도 같이 제거됨
- 비석(Tombstone)이 에이전트 위치에 생성됨
- 드래곤 위치에 열쇠가 드롭됨 → 다른 에이전트가 획득 가능

#### ResetScene() - 전체 리셋
```csharp
void ResetScene()
{
    m_ResetTimer = 0;
    m_NumberOfRemainingPlayers = AgentsList.Count;

    // 랜덤 플랫폼 회전 (0, 90, 180, 270도)
    var rotation = Random.Range(0, 4);
    transform.Rotate(new Vector3(0f, rotation * 90f, 0f));

    // 에이전트 리셋
    foreach (var item in AgentsList)
    {
        var pos = UseRandomAgentPosition ? GetRandomSpawnPos() : item.StartingPos;
        var rot = UseRandomAgentRotation ? GetRandomRot() : item.StartingRot;
        item.Agent.transform.SetPositionAndRotation(pos, rot);
        item.Rb.linearVelocity = Vector3.zero;
        item.Agent.MyKey.SetActive(false);
        item.Agent.IHaveAKey = false;
        item.Agent.gameObject.SetActive(true);
        m_AgentGroup.RegisterAgent(item.Agent);
    }

    // 키와 비석 리셋
    Key.SetActive(false);
    Tombstone.SetActive(false);

    // 드래곤 리셋
    foreach (var item in DragonsList)
    {
        item.Agent.transform.SetPositionAndRotation(item.StartingPos, item.StartingRot);
        item.Agent.SetRandomWalkSpeed();  // 랜덤 속도
        item.Agent.gameObject.SetActive(true);
    }
}
```

### 2.3 SimpleNPC.cs

드래곤 NPC의 간단한 AI입니다.

```csharp
public class SimpleNPC : MonoBehaviour
{
    public Transform target;     // 추적 대상
    private Rigidbody rb;
    public float walkSpeed = 1;

    void FixedUpdate()
    {
        dirToGo = target.position - transform.position;
        dirToGo.y = 0;
        rb.rotation = Quaternion.LookRotation(dirToGo);
        rb.MovePosition(transform.position + transform.forward * walkSpeed * Time.deltaTime);
    }

    public void SetRandomWalkSpeed()
    {
        walkSpeed = Random.Range(1f, 7f);
    }
}
```

- 항상 타겟(가장 가까운 에이전트)을 향해 이동
- `SetRandomWalkSpeed()`로 속도 랜덤화 (1~7)
- 학습된 AI가 아닌 간단한 규칙 기반 NPC

---

## 3. 관찰-액션-보상 구조

| 항목 | 내용 |
|------|------|
| **관찰** | 1차원 (키 보유 여부) |
| **액션** | 1차원 이산 (7개: None/전진/후진/좌회전/우회전/좌측/우측) |
| **보상** | 문 열기 성공 시 +1 (팀 전체) |
| **종료 조건** | 문 열기 성공, 모든 에이전트 사망, MaxStep 도달 |
| **특징** | SimpleMultiAgentGroup, 협력 플레이, NPC 드래곤 |

---

## 4. 학습 실행

### 4.1 학습 명령어
```bash
mlagents-learn config/ppo/DungeonEscape.yaml --run-id=DungeonEscapeTest1
```

### 4.2 학습 설정
```yaml
behaviors:
  DungeonEscape:
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
      hidden_units: 128
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

### 과제 1: 드래곤 전략 변경
- SimpleNPC의 이동 방식을 규칙 기반에서 RL 기반으로 변경
- 드래곤도 학습하는 2단계 환경 설계

### 과제 2: 키 시스템 확장
- 여러 개의 키가 필요한 문 구현
- 각기 다른 색상의 키와 매칭되는 자물쇠

### 과제 3: 생존 보상 추가
- 매 스텝마다 소량의 생존 보상 또는 패널티 추가
- 에이전트가 더 빠르게 탈출하도록 유도

### 과제 4: 드래곤 수 변경
- 드래곤 1마리 vs 3마리 비교 학습
- 드래곤 수에 따른 협력 전략 변화 관찰

### 과제 5: 시각 관찰 추가
- `CollectObservations`에 드래곤과의 거리, 포탈 위치 등 추가
- 관찰 정보가 많을수록 학습이 빨라지는지 확인

---

## 6. 전체 파일 구조와 각 파일의 의미

```
DungeonEscape/
├── Scenes/
│   └── DungeonEscape.unity                      # (1) 유일한 씬
│
├── Scripts/
│   ├── PushAgentEscape.cs                        # (2) 메인 에이전트
│   ├── DungeonEscapeEnvController.cs             # (3) 환경 관리자
│   └── SimpleNPC.cs                              # (4) 드래곤 NPC AI
│
├── Prefabs/
│   ├── DungeonEscapeAgent.prefab                 # (5) 에이전트 프리팹
│   └── DungeonEscapePlatform.prefab              # (6) 던전 플랫폼 프리팹
│
├── TFModels/
│   └── DungeonEscape.onnx                        # (7) 사전 학습 ONNX
│
└── Demos/
    └── ExpertDungeonEscape.demo                  # (8) 전문가 데모
```

---

### (1) `Scenes/DungeonEscape.unity` — 유일한 씬

**씬 계층 구조**:
```
DungeonEscape.unity
├── Main Camera
├── DungeonEscapeEnvController (환경 컨트롤러)
├── Platform (PushBlockSettings + DungeonEscapePlatform.prefab)
│   ├── PushAgentEscape × N (N명의 에이전트)
│   ├── Dragon (SimpleNPC)
│   ├── Key
│   ├── Locked Door (tag=lock)
│   ├── Portal (tag=portal)
│   ├── Tombstone
│   └── Walls/Floor
├── Academy (자동 생성, MA-POCA 그룹)
└── EventSystem
```

**협력 멀티 에이전트 환경**:
- N명의 에이전트가 협력하여 던전 탈출
- PushBlock 계열(이산 7개 액션)과 같은 이동 체계 사용

### (2) `Scripts/PushAgentEscape.cs` — 메인 에이전트

| 기능 | 설명 |
|------|------|
| 관찰 | **1차원** (키 보유 여부 boolean) |
| 액션 | 이산 7개 (정지/전진/후진/좌회전/우회전/좌측/우측) |
| 보상 | 개별 보상 없음 — EnvController가 그룹 보상 처리 |

```csharp
public override void CollectObservations(VectorSensor sensor)
{
    sensor.AddObservation(IHaveAKey);  // 단 1차원 관찰
}
```

**상호작용 처리**:
| 태그 | 충돌 시 | 결과 |
|------|--------|------|
| `"lock"` | 키 보유 중 | `UnlockDoor()` → 문 열림 |
| `"dragon"` | 드래곤과 충돌 | 사망 처리, 비석 생성, 키 드롭 |
| `"portal"` | 포탈 접촉 | 플레이어 제거 (탈출) |
| `"key"` | 트리거 | 키 획득 (`IHaveAKey = true`) |

### (3) `Scripts/DungeonEscapeEnvController.cs` — 환경 관리자

**SimpleMultiAgentGroup**을 사용한 협력형 환경 컨트롤러입니다.

```csharp
public class DungeonEscapeEnvController : MonoBehaviour
{
    public List<PlayerInfo> AgentsList;
    public List<DragonInfo> DragonsList;
    public GameObject Key;
    public GameObject Tombstone;

    private SimpleMultiAgentGroup m_AgentGroup;
}
```

| 메서드 | 역할 |
|--------|------|
| `Start()` | 에이전트 그룹 등록, 시작 위치 저장 |
| `TouchedHazard()` | 포탈 진입 — 모든 에이전트가 포탈 도착 시 종료 |
| `UnlockDoor()` | 문 열기 성공 — 그룹 보상 +1, 에피소드 종료 |
| `KilledByBaddie()` | 드래곤 사망 — 드래곤 제거, 키 드롭, 비석 생성 |
| `ResetScene()` | 모든 에이전트/키/드래곤 리셋, 플랫폼 회전 |

**리셋 특징**:
```csharp
// 플랫폼 전체를 랜덤 회전 (0/90/180/270도) → 일반화 학습
var rotation = Random.Range(0, 4);
transform.Rotate(new Vector3(0f, rotation * 90f, 0f));
```

### (4) `Scripts/SimpleNPC.cs` — 드래곤 NPC AI

규칙 기반의 간단한 적 AI입니다.

```csharp
public class SimpleNPC : MonoBehaviour
{
    public Transform target;     // 추적 대상 (가장 가까운 에이전트)
    public float walkSpeed = 1;

    void FixedUpdate()
    {
        // 항상 타겟 방향으로 이동
        dirToGo = target.position - transform.position;
        dirToGo.y = 0;
        rb.rotation = Quaternion.LookRotation(dirToGo);
        rb.MovePosition(transform.position + transform.forward * walkSpeed * Time.deltaTime);
    }

    public void SetRandomWalkSpeed()
    {
        walkSpeed = Random.Range(1f, 7f);  // 속도 랜덤화
    }
}
```

| 특징 | 설명 |
|------|------|
| 행동 | 가장 가까운 에이전트 추적 |
| 속도 | 1~7 (에피소드마다 랜덤) |
| 학습 여부 | 학습되지 않음 (규칙 기반) |

### (5) `Prefabs/DungeonEscapeAgent.prefab` — 에이전트 프리팹

```
DungeonEscapeAgent.prefab
├── PushAgentEscape (Agent)
├── Behavior Parameters
├── Rigidbody
├── Collider
└── Decision Requester
```

PushAgentBasic과 거의 동일한 구조이나 `IHaveAKey` 상태를 가짐.

### (6) `Prefabs/DungeonEscapePlatform.prefab` — 던전 플랫폼 프리팹

```
DungeonEscapePlatform.prefab
├── Ground/Floor
├── Walls (4면 경계)
├── Locked Door (tag=lock)
├── Portal × 2 (tag=portal)
├── Key (시작 시 비활성화)
├── Tombstone (시작 시 비활성화)
├── SpawnArea (에이전트 스폰 구역)
└── Dragon Spawn (드래곤 스폰 구역)
```

### (7) `TFModels/DungeonEscape.onnx` — 사전 학습 ONNX

| 항목 | 설명 |
|------|------|
| 학습기 | MA-POCA |
| 에이전트 | 4명 (협력) |
| 보상 | 그룹 보상 (문 열기 +1) |
| 액션 | 이산 7개 |
| 관찰 | 1차원 (키 보유 여부) |

### (8) `Demos/ExpertDungeonEscape.demo` — 전문가 데모

---

## 7. 핵심 포인트

- **협력형 멀티 에이전트** 환경 (SimpleMultiAgentGroup)
- 키-자물쇠 퍼즐 구조로 **순차적 협력** 필요
- NPC 드래곤이 에이전트를 추적하며 위험 요소 제공
- 드래곤에게 죽으면 **비석 생성 + 키 드롭** → 다른 에이전트가 이어받음
- 랜덤 플랫폼 회전(0/90/180/270도)으로 일반화 학습
- 랜덤 스폰 위치와 회전으로 다양한 시작 조건
- 드래곤 이동 속도 랜덤화 (1~7)로 난이도 변동
- 단순한 관찰 공간(1차원)으로도 협력 행동 학습 가능
