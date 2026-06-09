# Match3 예제 가이드

## 1. 개요

Match3는 퍼즐 게임 장르의 전형적인 "3매치" 게임을 위한 ML-Agents 환경입니다.
플레이어는 타일을 교체하여 3개 이상의 같은 타일을 매치시키고 점수를 얻습니다.
이 환경은 ML-Agents의 Match3 통합 기능(AbstractBoard, Match3Actuator)을
활용한 커스텀 액추에이터 사용 예제입니다.

**목표**: 타일을 교체하여 매치를 만들고 최대 점수 획득하기

### 게임 구조

```
   Col:  0    1    2    3    4
   ┌────┬────┬────┬────┬────┐
 0 │ R  │ G  │ B  │ C  │ M  │
   ├────┼────┼────┼────┼────┤
 1 │ G  │ B  │ R  │ Y  │ G  │
   ├────┼────┼────┼────┼────┤
 2 │ B  │ Y  │ G  │ R  │ Y  │
   ├────┼────┼────┼────┼────┤
 3 │ R  │ G  │ B  │ G  │ B  │
   ├────┼────┼────┼────┼────┤
 4 │ Y  │ R  │ Y  │ B  │ C  │
   └────┴────┴────┴────┴────┘
   R: Red, G: Green, B: Blue, C: Cyan, M: Magenta, Y: Yellow
```

---

## 2. 코드 분석

### 2.1 Match3Agent.cs

3매치 게임의 에이전트로, 보드 상태를 관리하고 액션을 요청합니다.

```csharp
namespace Unity.MLAgentsExamples
{
    enum State
    {
        Invalid = -1,
        FindMatches = 0,    // 매치 찾기
        ClearMatched = 1,   // 매치된 타일 제거
        Drop = 2,           // 타일 아래로 내리기
        FillEmpty = 3,      // 빈 칸 새 타일로 채우기
        WaitForMove = 4,    // 에이전트의 움직임 대기
    }

    public class Match3Agent : Agent
    {
        [HideInInspector] public Match3Board Board;
        public float MoveTime = 1.0f;
        public int MaxMoves = 500;

        State m_CurrentState = State.WaitForMove;
        float m_TimeUntilMove;
        private int m_MovesMade;

        private const float k_RewardMultiplier = 0.01f;
    }
}
```

#### 게임 상태 머신 (State Machine)

```
      ┌─────────────────────────────────────────────┐
      │                                             │
      v                                             │
  [FindMatches] ──매치 있음──→ [ClearMatched] ──→ [Drop] ──→ [FillEmpty] ──→ [FindMatches]
       │                                              ↑
       │ 매치 없음                                    │
       v                                              │
  [WaitForMove] ──에이전트 액션→ [FindMatches] ──────┘
```

#### FastUpdate() - 학습 모드 (즉시 처리)
```csharp
void FastUpdate()
{
    while (true)
    {
        var hasMatched = Board.MarkMatchedCells();
        if (!hasMatched) break;

        var pointsEarned = Board.ClearMatchedCells();
        AddReward(k_RewardMultiplier * pointsEarned);  // 체인 보상
        Board.DropCells();
        Board.FillFromAbove();
    }

    while (!HasValidMoves())
        Board.InitSettled();  // 유효한 움직임이 없으면 리셔플

    RequestDecision();
    m_MovesMade++;
}
```

- 학습 시 while 루프로 체인 매치를 즉시 처리
- 체인 매치마다 보상 추가 (0.01 × 점수)
- 유효한 움직임이 없을 때까지 보드 리셔플
- 매 move마다 `RequestDecision()` 호출

#### AnimatedUpdate() - 비학습 모드 (애니메이션)
```csharp
void AnimatedUpdate()
{
    m_TimeUntilMove -= Time.deltaTime;
    if (m_TimeUntilMove > 0.0f) return;
    m_TimeUntilMove = MoveTime;

    switch (m_CurrentState)
    {
        case State.FindMatches:
            var hasMatched = Board.MarkMatchedCells();
            nextState = hasMatched ? State.ClearMatched : State.WaitForMove;
            break;
        case State.ClearMatched:
            var pointsEarned = Board.ClearMatchedCells();
            AddReward(k_RewardMultiplier * pointsEarned);
            nextState = State.Drop;
            break;
        case State.Drop:
            Board.DropCells();
            nextState = State.FillEmpty;
            break;
        case State.FillEmpty:
            Board.FillFromAbove();
            nextState = State.FindMatches;
            break;
        case State.WaitForMove:
            // 유효한 움직임 확인
            while (!HasValidMoves()) Board.InitSettled();
            RequestDecision();
            nextState = State.FindMatches;
            break;
    }
}
```

- `MoveTime` 간격으로 상태 전환 (애니메이션 목적)
- 플레이어가 시각적으로 변화를 볼 수 있음

#### FixedUpdate() - 에피소드 관리
```csharp
private void FixedUpdate()
{
    var useFast = Academy.Instance.IsCommunicatorOn || (m_ModelOverrider != null && m_ModelOverrider.HasOverrides);
    if (useFast)
        FastUpdate();
    else
        AnimatedUpdate();

    if (m_MovesMade >= MaxMoves)
        EpisodeInterrupted();
}
```

### 2.2 Match3Board.cs

3매치 보드의 핵심 로직을 담당합니다. `AbstractBoard`를 상속받아
ML-Agents Match3 통합 기능을 사용합니다.

```csharp
public class Match3Board : AbstractBoard
{
    public int MinRows, MaxRows;
    public int MinColumns, MaxColumns;
    public int NumCellTypes;
    public int NumSpecialTypes;
    public const int k_EmptyCell = -1;
    public int BasicCellPoints = 1;
    public int SpecialCell1Points = 2;
    public int SpecialCell2Points = 3;

    (int CellType, int SpecialType)[,] m_Cells;
    bool[,] m_Matched;
    private BoardSize m_CurrentBoardSize;
}
```

#### MakeMove() - 타일 교체
```csharp
public override bool MakeMove(Move move)
{
    if (!IsMoveValid(move)) return false;

    var originalValue = m_Cells[move.Column, move.Row];
    var (otherRow, otherCol) = move.OtherCell();
    var destinationValue = m_Cells[otherCol, otherRow];

    m_Cells[move.Column, move.Row] = destinationValue;
    m_Cells[otherCol, otherRow] = originalValue;
    return true;
}
```

- `Move` 객체가 지정한 두 셀의 값을 교환
- `AbstractBoard`의 `Move` 구조를 활용

#### MarkMatchedCells() - 매치 찾기
```csharp
public bool MarkMatchedCells(int[,] cells = null)
{
    ClearMarked();
    bool madeMatch = false;
    for (var i = 0; i < m_CurrentBoardSize.Rows; i++)
    {
        for (var j = 0; j < m_CurrentBoardSize.Columns; j++)
        {
            // 세로 방향 매치 확인
            var matchedRows = 0;
            for (var iOffset = i; iOffset < m_CurrentBoardSize.Rows; iOffset++)
            {
                if (m_Cells[j, i].CellType != m_Cells[j, iOffset].CellType) break;
                matchedRows++;
            }
            if (matchedRows >= 3)
            {
                madeMatch = true;
                for (var k = 0; k < matchedRows; k++)
                    m_Matched[j, i + k] = true;
            }

            // 가로 방향 매치 확인
            var matchedCols = 0;
            for (var jOffset = j; jOffset < m_CurrentBoardSize.Columns; jOffset++)
            {
                if (m_Cells[j, i].CellType != m_Cells[jOffset, i].CellType) break;
                matchedCols++;
            }
            if (matchedCols >= 3)
            {
                madeMatch = true;
                for (var k = 0; k < matchedCols; k++)
                    m_Matched[j + k, i] = true;
            }
        }
    }
    return madeMatch;
}
```

- 각 셀에서 세로/가로 방향으로 같은 타일이 3개 이상 연속인지 확인
- 3개 이상이면 `m_Matched` 배열에 마킹

#### ClearMatchedCells() - 매치 제거 및 점수 계산
```csharp
public int ClearMatchedCells()
{
    var pointsByType = new[] { BasicCellPoints, SpecialCell1Points, SpecialCell2Points };
    int pointsEarned = 0;
    for (var i = 0; i < m_CurrentBoardSize.Rows; i++)
    {
        for (var j = 0; j < m_CurrentBoardSize.Columns; j++)
        {
            if (m_Matched[j, i])
            {
                var specialType = GetSpecialType(i, j);
                pointsEarned += pointsByType[specialType];
                m_Cells[j, i] = (k_EmptyCell, 0);
            }
        }
    }
    ClearMarked();
    return pointsEarned;
}
```

**타일별 점수**:
| 타일 종류 | 점수 |
|-----------|------|
| BasicCell (일반) | 1 |
| SpecialCell1 (구체) | 2 |
| SpecialCell2 (십자가) | 3 |

#### DropCells() / FillFromAbove() - 중력 및 채우기
```csharp
public bool DropCells()
{
    // 아래 방향으로 타일 이동 (중력)
    for (var j = 0; j < m_CurrentBoardSize.Columns; j++)
    {
        var writeIndex = 0;
        for (var readIndex = 0; readIndex < m_CurrentBoardSize.Rows; readIndex++)
        {
            m_Cells[j, writeIndex] = m_Cells[j, readIndex];
            if (m_Cells[j, readIndex].CellType != k_EmptyCell)
                writeIndex++;
        }
        for (; writeIndex < m_CurrentBoardSize.Rows; writeIndex++)
            m_Cells[j, writeIndex] = (k_EmptyCell, 0);
    }
}

public bool FillFromAbove()
{
    // 빈 셀을 새 랜덤 타일로 채우기
    for (var i = 0; i < m_CurrentBoardSize.Rows; i++)
        for (var j = 0; j < m_CurrentBoardSize.Columns; j++)
            if (m_Cells[j, i].CellType == k_EmptyCell)
                m_Cells[j, i] = (GetRandomCellType(), GetRandomSpecialType());
}
```

#### InitSettled() - 안정화된 보드 초기화
```csharp
public void InitSettled()
{
    InitRandom();
    while (true)
    {
        var anyMatched = MarkMatchedCells();
        if (!anyMatched) return;
        ClearMatchedCells();
        DropCells();
        FillFromAbove();
    }
}
```

- 랜덤 보드 생성 후 매치가 없을 때까지 반복 제거
- 항상 유효한 움직임이 있는 보드 상태 보장

### 2.3 Match3ExampleActuator.cs

Match3용 커스텀 액추에이터로, 각 움직임의 점수를 예측합니다.

```csharp
public class Match3ExampleActuator : Match3Actuator
{
    protected override int EvalMovePoints(Move move)
    {
        // 양쪽 방향의 예상 점수 합산
        int movePoints = EvalHalfMove(otherRow, otherCol, moveVal, moveSpecial, move.Direction, pointsByType);
        int otherPoints = EvalHalfMove(move.Row, move.Column, oppositeVal, oppositeSpecial, move.OtherDirection(), pointsByType);
        return movePoints + otherPoints;
    }

    int EvalHalfMove(int newRow, int newCol, int newValue, int newSpecial, Direction incomingDirection, int[] pointsByType)
    {
        // 4방향으로 같은 타일 개수와 점수 계산
        // (matchedUp + matchedDown >= 2) || (matchedLeft + matchedRight >= 2) 이면 매치 성립
        // 매치된 타일들의 점수 합산 반환
    }
}
```

- `Match3Actuator`를 상속받아 커스텀 점수 평가 함수 제공
- Heuristic 모드에서 가장 높은 점수의 움직임 선택 가능

### 2.4 Match3ExampleActuatorComponent.cs

```csharp
public class Match3ExampleActuatorComponent : Match3ActuatorComponent
{
    public override IActuator[] CreateActuators()
    {
        var board = GetComponent<Match3Board>();
        var seed = RandomSeed == -1 ? gameObject.GetInstanceID() : RandomSeed + 1;
        return new IActuator[] { new Match3ExampleActuator(board, ForceHeuristic, ActuatorName, seed) };
    }
}
```

### 2.5 Match3Drawer.cs

보드 상태를 시각화하는 드로어입니다. 각 타일의 색상과 특수 타입을
Gizmos와 실제 오브젝트로 표시하고 유효한 움직임을 선으로 표시합니다.

### 2.6 Match3TileSelector.cs

개별 타일의 시각적 표시를 관리합니다. 타일 타입과 머티리얼 인덱스에 따라
적절한 게임 오브젝트와 머티리얼을 활성화합니다.

---

## 3. 관찰-액션-보상 구조

| 항목 | 내용 |
|------|------|
| **관찰** | AbstractBoard가 자동 제공 (보드 상태, 타일 타입 등) |
| **액션** | Match3Actuator가 제공 (인접 타일 교체) |
| **보상** | 매치 타일 점수 × 0.01 (체인 매치 누적) |
| **종료 조건** | MaxMoves(500) 도달 |
| **특징** | 커스텀 Actuator, Match3 통합 API, 가변 보드 크기 |

---

## 4. 학습 실행

### 4.1 학습 명령어
```bash
mlagents-learn config/ppo/Match3.yaml --run-id=Match3Test1
```

### 4.2 학습 설정
```yaml
behaviors:
  Match3:
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

### 과제 1: 보드 크기 가변 학습
- `MinRows=5, MaxRows=8`, `MinColumns=5, MaxColumns=8`로 설정
- 다양한 보드 크기에서 일반화된 전략 학습

### 과제 2: 특수 타일 점수 변경
- `SpecialCell1Points`와 `SpecialCell2Points` 값을 변경
- 특수 타일 우선 전략 vs 일반 타일 위주 전략 비교

### 과제 3: 보상 스케일 조정
- `k_RewardMultiplier`를 0.01에서 0.1, 0.001로 변경
- 보상 크기가 학습 속도에 미치는 영향 분석

### 과제 4: 최대 움직임 제한 변경
- `MaxMoves`를 500에서 200, 1000으로 변경
- 적은 움직임에서의 효율적 전략 학습

### 과제 5: 매치 조건 변경
- 3매치에서 4매치로 조건 변경
- 더 긴 매치에 높은 보너스 부여

---

## 6. 전체 파일 구조와 각 파일의 의미

```
Match3/
├── Scenes/
│   └── Match3.unity                                # (1) 유일한 씬
│
├── Scripts/
│   ├── Match3Agent.cs                              # (2) 메인 에이전트 (State Machine)
│   ├── Match3Board.cs                              # (3) 보드 로직 (AbstractBoard)
│   ├── Match3ExampleActuator.cs                    # (4) 커스텀 액추에이터 (Match3Actuator)
│   ├── Match3ExampleActuatorComponent.cs           # (5) 액추에이터 컴포넌트
│   ├── Match3Drawer.cs                             # (6) 보드 시각화 (Gizmos)
│   └── Match3TileSelector.cs                       # (7) 타일 시각화 (머티리얼)
│
└── TFModels/
    └── Match3.onnx                                 # (8) 사전 학습 ONNX
```

---

### (1) `Scenes/Match3.unity` — 유일한 씬

**씬 계층 구조**:
```
Match3.unity
├── Main Camera (직교 투영)
├── Directional Light
├── Match3
│   ├── Match3Agent (Match3Agent.cs)
│   ├── Match3Board (Match3Board.cs)
│   ├── Match3ExampleActuatorComponent
│   ├── Match3Drawer (Match3Drawer.cs)
│   └── Match3TileSelector (Match3TileSelector.cs)
└── EventSystem
```

**2D 게임 스타일**: 카메라는 직교 투영(Orthographic)으로 보드를 내려다봄.
씬에 물리 오브젝트나 Rigidbody가 없음 — 순수한 로직 기반 환경.

### (2) `Scripts/Match3Agent.cs` — 메인 에이전트

Match3 게임의 전체 상태를 관리하는 **상태 머신**입니다.

```csharp
public class Match3Agent : Agent
{
    public Match3Board Board;
    public float MoveTime = 1.0f;
    public int MaxMoves = 500;

    const float k_RewardMultiplier = 0.01f;
}
```

**상태 머신**:
```
FindMatches → ClearMatched → Drop → FillEmpty → FindMatches
                                      ↓
                                 WaitForMove
```
- **FastUpdate()** (학습 모드): 체인 매치를 루프로 즉시 처리
- **AnimatedUpdate()** (표시 모드): MoveTime 간격으로 천천히 처리

**보상**: `k_RewardMultiplier * pointsEarned` (체인 매치 누적)

### (3) `Scripts/Match3Board.cs` — 보드 로직 (AbstractBoard)

**AbstractBoard 상속**: ML-Agents의 Match3 통합 API를 활용합니다.

```csharp
public class Match3Board : AbstractBoard
{
    public int MinRows = 5, MaxRows = 8;
    public int MinColumns = 5, MaxColumns = 8;
    public int NumCellTypes;
    public int NumSpecialTypes;
    public int BasicCellPoints = 1;
    public int SpecialCell1Points = 2;
    public int SpecialCell2Points = 3;
}
```

| 메서드 | 역할 |
|--------|------|
| `MarkMatchedCells()` | 가로/세로 3개 이상 연속 타일 마킹 |
| `ClearMatchedCells()` | 마킹된 타일 제거 + 점수 계산 |
| `DropCells()` | 빈 공간으로 타일 하강 (중력) |
| `FillFromAbove()` | 빈 셀을 새 랜덤 타일로 채움 |
| `MakeMove(Move)` | 타일 교체 (AbstractBoard 인터페이스) |
| `InitSettled()` | 매치 없는 안정화된 보드 생성 |

**타일별 점수**:

| 타일 종류 | 점수 |
|-----------|------|
| BasicCell (일반 타일) | 1 |
| SpecialCell1 (구체 모양) | 2 |
| SpecialCell2 (십자가 모양) | 3 |

**체인 매치 처리**: FastUpdate에서 while 루프로 여러 단계의 매치를 한 번에 처리

### (4) `Scripts/Match3ExampleActuator.cs` — 커스텀 액추에이터

`Match3Actuator`를 상속받아 커스텀 점수 평가 함수를 제공합니다.

```csharp
public class Match3ExampleActuator : Match3Actuator
{
    protected override int EvalMovePoints(Move move)
    {
        // 양방향 예상 점수 합산
        int movePoints = EvalHalfMove(otherRow, otherCol, moveVal, ...);
        int otherPoints = EvalHalfMove(move.Row, move.Column, oppositeVal, ...);
        return movePoints + otherPoints;
    }
}
```

**Heuristic 모드**에서 가장 높은 예상 점수의 움직임을 선택할 수 있음.
학습 시에는 신경망이 점수 평가를 학습.

### (5) `Scripts/Match3ExampleActuatorComponent.cs` — 액추에이터 컴포넌트

```csharp
public class Match3ExampleActuatorComponent : Match3ActuatorComponent
{
    public override IActuator[] CreateActuators()
    {
        return new IActuator[] {
            new Match3ExampleActuator(board, ForceHeuristic, ActuatorName, seed)
        };
    }
}
```

### (6) `Scripts/Match3Drawer.cs` — 보드 시각화

**Gizmos**를 사용하여 보드 상태를 시각화합니다.
- 각 셀의 타일 타입을 색상으로 표시
- 유효한 움직임을 선으로 표시
- 현재 선택된 타일 강조

### (7) `Scripts/Match3TileSelector.cs` — 타일 시각화

개별 타일의 시각적 표시를 관리합니다. 타일 타입과 특수 타입에 따라
해당하는 머티리얼을 활성화/비활성화합니다.

### (8) `TFModels/Match3.onnx` — 사전 학습 ONNX

| 항목 | 설명 |
|------|------|
| 학습기 | PPO |
| 보드 크기 | 5×5 ~ 8×8 (가변) |
| 타일 종류 | 6가지 기본 + 3가지 특수 타입 |
| 액션 | 인접 타일 교체 (Match3Actuator 제공) |
| 특이사항 | AbstractBoard + Match3Actuator 통합 API 사용 |

---

## 7. 핵심 포인트

- **ML-Agents Match3 통합 API** (`AbstractBoard`, `Match3Actuator`) 활용
- **커스텀 Actuator**로 게임 특화 움직임 점수 평가
- 상태 머신 기반 게임 로직 (FindMatches → Clear → Drop → Fill)
- 학습 모드(FastUpdate)와 표시 모드(AnimatedUpdate) 분리
- **가변 보드 크기**로 일반화 학습 지원
- 3가지 타일 타입 (일반/구체/십자가)과 차별화된 점수
- 체인 매치 보상으로 장기 전략 학습 유도
- Gizmos를 통한 유효 움직임 시각화
- InitSettled()로 항상 유효한 초기 보드 보장
