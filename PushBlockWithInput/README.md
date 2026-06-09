# PushBlockWithInput 예제 가이드

## 1. 개요

PushBlockWithInput은 Unity Input System을 ML-Agents와 통합하는 방법을 보여주는 예제입니다.
기본 PushBlock에 **Unity Input System 패키지**를 접목하여, 사람의 입력(키보드/게임패드)과 
에이전트의 의사결정을 동일한 액션 공간에서 처리합니다.

**목표**: Input System을 통해 사람이 직접 제어하거나, AI가 학습하여 블록을 목표까지 밀기

### 주요 특징
- Unity Input System (`InputActionAsset`)과 ML-Agents 통합
- `IInputActionAssetProvider` 인터페이스 구현
- `InputActuatorComponent`를 통한 자동 액션 바인딩
- 사람 플레이와 AI 학습이 동일한 입력 체계 사용
- 점프 기능 추가 (기본 PushBlock과의 차이점)

---

## 2. 코드 분석

### 2.1 PushBlockWithInputAgentBasic.cs

Agent 클래스로, 기본 PushBlockAgent와 유사하지만 점프 기능이 추가되었습니다.

```csharp
public class PushBlockWithInputAgentBasic : Agent
{
    public GameObject ground;
    public GameObject area;
    public Bounds areaBounds;
    public GameObject block;
    public GoalDetectWithInput goalDetect;
}
```

#### 주요 차이점 (기본 PushBlock 대비)
- `goalDetect` 타입이 `GoalDetectWithInput`으로 변경
- 점프 관련 코드 없음 (점프는 PlayerController에서 처리)
- `OnActionReceived()`에서 액션 처리 없이 패널티만 부여

```csharp
public override void OnActionReceived(ActionBuffers actionBuffers)
{
    AddReward(-1f / MaxStep);  // 시간 패널티만 부여
}
```

- 실제 이동은 `InputActuatorComponent`가 Input System을 통해 처리
- Agent는 보상과 에피소드 관리만 담당

### 2.2 PushBlockWithInputPlayerController.cs

Input System과 통합되는 핵심 스크립트입니다.

```csharp
public class PushBlockWithInputPlayerController : MonoBehaviour, IInputActionAssetProvider
{
    PushBlockWithInputSettings m_PushBlockSettings;
    public float JumpTime = 0.5f;
    float m_JumpTimeRemaining;
    Rigidbody m_PlayerRb;
    PushBlockActions m_PushBlockActions;
}
```

#### IInputActionAssetProvider 인터페이스
```csharp
public (InputActionAsset, IInputActionCollection2) GetInputActionAsset()
{
    LazyInitializeActions();
    return (m_PushBlockActions.asset, m_PushBlockActions);
}
```

- `InputActuatorComponent`가 이 인터페이스를 찾아 액션을 자동 바인딩
- 학습 시에는 가상 컨트롤러로, 추론 시에는 실제 입력 장치로 동작

#### 입력 처리 - FixedUpdate()
```csharp
void FixedUpdate()
{
    InputMove(gameObject.transform, m_PushBlockActions.Movement.movement.ReadValue<Vector2>());
    if (m_JumpTimeRemaining < 0)
        m_PlayerRb.AddForce(-transform.up * (m_PushBlockSettings.agentJumpForce * 3), ForceMode.Acceleration);
    m_JumpTimeRemaining -= Time.fixedDeltaTime;
}

void InputMove(Transform t, Vector2 v)
{
    var forward = CreateForwardVector(v);
    var up = CreateUpVector(v);
    var dirToGo = t.forward * forward;
    var rotateDir = t.up * up;
    t.Rotate(rotateDir, Time.deltaTime * 200f);
    m_PlayerRb.AddForce(dirToGo * m_PushBlockSettings.agentRunSpeed, ForceMode.VelocityChange);
}
```

- `movement` 액션에서 Vector2 값을 읽어 이동 방향 결정
- 점프는 이벤트 기반(`performed`)으로 처리

#### 점프 처리
```csharp
void LazyInitializeActions()
{
    m_PushBlockActions = new PushBlockActions();
    m_PushBlockActions.Enable();
    m_PushBlockActions.Movement.jump.performed += JumpOnperformed;
}

void JumpOnperformed(InputAction.CallbackContext callbackContext)
{
    InnerJump(gameObject.transform);
}

void InnerJump(Transform t)
{
    if (Time.realtimeSinceStartup - m_JumpCoolDownStart > m_PushBlockSettings.agentJumpCoolDown)
    {
        m_JumpTimeRemaining = JumpTime;
        m_PlayerRb.AddForce(t.up * m_PushBlockSettings.agentJumpForce, ForceMode.VelocityChange);
        m_JumpCoolDownStart = Time.realtimeSinceStartup;
    }
}
```

- 점프는 쿨다운 시스템으로 제한됨
- `agentJumpForce`와 `agentJumpCoolDown`으로 점프 파라미터 조절

### 2.3 PushBlockActions.cs (자동 생성 코드)

Unity Input System 패키지가 `PushBlockActions.inputactions`에서 자동 생성한 코드입니다.

```csharp
public partial class @PushBlockActions : IInputActionCollection2, IDisposable
{
    public InputActionAsset asset { get; }
    
    // Movement 액션 맵
    public struct MovementActions
    {
        public InputAction @movement;  // Vector2 (WASD/게임패드)
        public InputAction @jump;      // Button (Space/게임패드 버튼)
    }
    public MovementActions @Movement => new MovementActions(this);
}
```

**정의된 입력 액션**:
| 액션 | 타입 | 바인딩 |
|------|------|--------|
| Movement/movement | Vector2 | WASD, 게임패드 D패드 |
| Movement/jump | Button | Space, 게임패드 South 버튼 |

### 2.4 PushBlockWithInputSettings.cs

```csharp
public class PushBlockWithInputSettings : MonoBehaviour
{
    public float agentRunSpeed;
    public float agentRotationSpeed;
    public float agentJumpForce;         // 점프 힘
    public float agentJumpCoolDown;      // 점프 쿨다운
    public float spawnAreaMarginMultiplier;
    public Material goalScoredMaterial;
    public Material failMaterial;
}
```

- 기본 PushBlockSettings에 점프 관련 파라미터 추가

### 2.5 GoalDetectWithInput.cs

```csharp
public class GoalDetectWithInput : MonoBehaviour
{
    [HideInInspector]
    public PushBlockWithInputAgentBasic agent;

    void OnCollisionEnter(Collision col)
    {
        if (col.gameObject.CompareTag("goal"))
            agent.ScoredAGoal();
    }
}
```

---

## 3. Input System 통합 아키텍처

```
                    학습 모드                          추론 모드
                    
  [Python Trainer] → [RPC Communicator]            [키보드/게임패드]
                           ↓                            ↓
              [InputActuatorComponent]         [InputActuatorComponent]
                           ↓                            ↓
              [가상 컨트롤러 생성]              [실제 입력 장치 사용]
                           ↓                            ↓
              [PushBlockActions.InputActionAsset] (동일한 액션 맵)
                           ↓
              [PushBlockWithInputPlayerController]
                           ↓
                    [Rigidbody 이동/점프]
```

### IInputActionAssetProvider 인터페이스
- `InputActuatorComponent`가 이 인터페이스를 구현한 컴포넌트를 찾음
- 학습 시: Python 트레이너의 결정을 가상 입력으로 변환
- 추론 시: 실제 키보드/게임패드 입력 사용
- 사람이 직접 플레이하면서 데모 녹화 가능

---

## 4. PushBlock vs PushBlockWithInput 비교

| 특징 | PushBlock | PushBlockWithInput |
|------|-----------|-------------------|
| **입력 시스템** | 수동 Heuristic() | Unity Input System |
| **액션 공간** | 수동 정의 (Discrete 7) | InputActionAsset 기반 |
| **점프** | 없음 | 있음 |
| **사람 플레이** | 키보드 직접 매핑 | Input System 액션 맵 |
| **데모 녹화** | Heuristic 모드 | Input System 이벤트 |
| **설정 스크립트** | PushBlockSettings | PushBlockWithInputSettings |

---

## 5. 학습 실행

### 5.1 학습 설정
```bash
mlagents-learn config/ppo/PushBlock.yaml --run-id=PushBlockInput1
```

### 5.2 사람 플레이 (Heuristic)
1. Unity 에디터에서 PushBlockWithInput 씬 열기
2. Play 모드 실행
3. WASD로 이동, Space로 점프

---

## 6. 실습 과제

### 과제 1: 새로운 입력 액션 추가
- Input Action Asset에 "sprint" 액션을 추가하고 Shift 키에 바인딩
- `PushBlockWithInputPlayerController`에서 sprint 시 이동 속도 2배로 처리

**힌트**: 
1. `PushBlockActions.inputactions`에 새 액션 추가
2. 자동 생성 코드 리프레시
3. `InnerMove()`에서 sprint 여부 확인 후 속도 변경

### 과제 2: 게임패드 지원 확장
- 조이스틱 아날로그 입력을 지원하도록 바인딩 추가
- 트리거 버튼을 점프에 매핑

### 과제 3: 멀티 입력 소스
- 2명의 플레이어가 각각 키보드와 게임패드로 동시에 조작
- 각 플레이어별로 별도의 InputActionAsset 인스턴스 사용

### 과제 4: 하이브리드 모드
- AI가 이동을 제어하고 사람이 점프만 담당하도록 분할
- `InputActuatorComponent`의 액션별 활성화/비활성화 활용

---

## 7. 전체 파일 구조와 각 파일의 의미

```
PushBlockWithInput/
├── Scenes/
│   └── PushBlockWithInput.unity              # (1) 유일한 씬
│
├── Scripts/
│   ├── PushBlockWithInputAgentBasic.cs        # (2) Agent
│   ├── PushBlockWithInputPlayerController.cs  # (3) Input System 통합
│   ├── PushBlockWithInputSettings.cs          # (4) 설정 (점프 파라미터)
│   ├── PushBlockActions.cs                    # (5) 자동 생성 Input 코드
│   └── GoalDetectWithInput.cs                 # (6) 충돌 감지
│
├── Prefabs/
│   └── PushBlockWithInputArea.prefab          # (7) 영역 프리팹
│
├── TFModels/
│   └── PushBlock.onnx                         # (8) 사전 학습 ONNX
│
└── PushBlockActions.inputactions              # (9) Input Action Asset
```

---

### (1) `Scenes/PushBlockWithInput.unity` — 유일한 씬

기본 PushBlock과 달리 한 가지씬만 있습니다. 점프 기능이 추가되어 있고
Input System이 통합된 버전입니다.

**씬 계층 구조**:
```
PushBlockWithInput.unity
├── Main Camera
├── PushBlockWithInputSettings  ← PushBlockWithInputSettings.cs
├── Area (PushBlockWithInputArea.prefab)
│   ├── PushBlockWithInputAgentBasic
│   ├── PushBlockWithInputPlayerController
│   │   └── IInputActionAssetProvider 구현
│   ├── Block
│   ├── Goal
│   └── Walls/Floor
├── Academy (자동 생성)
└── EventSystem
```

### (2) `Scripts/PushBlockWithInputAgentBasic.cs` — Agent

**기본 PushBlock과의 핵심 차이**: Agent는 더 이상 이동을 직접 처리하지 않습니다.

```csharp
public override void OnActionReceived(ActionBuffers actionBuffers)
{
    // 이동/점프는 InputActuatorComponent가 처리
    AddReward(-1f / MaxStep);  // 시간 패널티만 부여
}
```

Agent는 오직 **보상 지급**과 **에피소드 관리**만 담당하고,
실제 이동은 `InputActuatorComponent` → `InputActionAsset` → `PlayerController`로
이어지는 체인이 처리합니다.

### (3) `Scripts/PushBlockWithInputPlayerController.cs` — Input System 통합

**IInputActionAssetProvider 인터페이스**의 구현체로, ML-Agents와 Input System을 연결합니다.

```csharp
public class PushBlockWithInputPlayerController : MonoBehaviour, IInputActionAssetProvider
{
    // InputActuatorComponent가 이 메서드를 호출하여 액션 바인딩
    public (InputActionAsset, IInputActionCollection2) GetInputActionAsset()
    {
        LazyInitializeActions();
        return (m_PushBlockActions.asset, m_PushBlockActions);
    }
}
```

**동작 모드에 따른 차이**:
| 모드 | 입력 소스 | 동작 |
|------|----------|------|
| 학습 중 | InputActuatorComponent의 가상 컨트롤러 | Python 트레이너의 결정을 InputAction으로 변환 |
| 추론 중 | 실제 키보드/게임패드 | 사람이 WASD/Space로 직접 조작 |
| Heuristic | 키보드 | `InputActuatorComponent`가 Heuristic 호출 |

### (4) `Scripts/PushBlockWithInputSettings.cs` — 설정

```csharp
public class PushBlockWithInputSettings : MonoBehaviour
{
    public float agentRunSpeed;
    public float agentRotationSpeed;
    public float agentJumpForce;         // 점프 힘 (추가)
    public float agentJumpCoolDown;      // 점프 쿨다운 간격 (추가)
    public float spawnAreaMarginMultiplier;
    public Material goalScoredMaterial;
    public Material failMaterial;
}
```

기본 PushBlockSettings에 `agentJumpForce`와 `agentJumpCoolDown`이 추가되었습니다.

### (5) `Scripts/PushBlockActions.cs` — 자동 생성 코드

Unity Input System 패키지가 `PushBlockActions.inputactions`를 기반으로
자동 생성한 C# 코드입니다.

```csharp
// PushBlockActions — 자동 생성 (수정하지 말 것)
public partial class @PushBlockActions : IInputActionCollection2
{
    // Movement 액션 맵
    public InputActionMap @Movement;  // @Movement, @jump 등 자동 생성
}
```

**이 파일은 직접 수정하면 안 됩니다**. Input Action Asset을 변경한 후
Inspector의 "Save Asset" 버튼을 누르면 자동으로 재생성됩니다.

### (6) `Scripts/GoalDetectWithInput.cs` — 충돌 감지

기본 PushBlock의 `GoalDetect.cs`와 동일한 역할입니다. Goal 충돌 시
`PushBlockWithInputAgentBasic.ScoredAGoal()`을 호출합니다.

### (7) `Prefabs/PushBlockWithInputArea.prefab` — 영역 프리팹

기본 PushBlockArea와의 차이점:
- `PushBlockWithInputAgentBasic` 사용 (Agent 역할 축소)
- `PushBlockWithInputPlayerController` 포함 (Input System 연동)
- `Behavior Parameters`의 `Actuators`에 `InputActuatorComponent` 포함
- 점프 기능을 위한 물리 설정 포함

### (8) `TFModels/PushBlock.onnx` — 사전 학습 ONNX

기본 PushBlock과 동일한 모델을 공유합니다. 학습과 추론이 Input System을 통해
이루어지므로 네트워크 구조와 입력/출력이 PushBlock과 호환됩니다.

### (9) `PushBlockActions.inputactions` — Input Action Asset

Unity Input System의 설정 파일입니다. JSON 형식으로 저장됩니다.

```json
{
    "maps": [
        {
            "name": "Movement",
            "actions": [
                { "name": "movement", "type": "Value", "expectedControlType": "Vector2" },
                { "name": "jump", "type": "Button" }
            ],
            "bindings": [
                { "path": "<Keyboard>/w", "action": "movement" },
                { "path": "<Keyboard>/space", "action": "jump" }
            ]
        }
    ]
}
```

| 입력 액션 | 타입 | 키보드 바인딩 | 게임패드 바인딩 |
|----------|------|-------------|---------------|
| Movement/movement | Vector2 | WASD | 왼쪽 스틱 |
| Movement/jump | Button | Space | South 버튼 |

---

## 8. 핵심 포인트

- Unity Input System과 ML-Agents의 통합 방법 제시
- `IInputActionAssetProvider` 인터페이스를 통한 자동 액션 바인딩
- 학습/추론 모두 동일한 InputActionAsset 사용
- 사람 플레이와 AI 학습의 자연스러운 전환
- `InputActuatorComponent`가 가상 컨트롤러를 생성하여 학습 지원
- C# 이벤트와 폴링 방식을 혼합한 입력 처리 패턴
