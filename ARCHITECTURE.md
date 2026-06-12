# Couples Finance App - Architecture Overview

## 📁 Folder Structure

```
lib/
├── main.dart                    # App 入口，Firebase 初始化
├── firebase_options.dart        # Firebase 設定檔
│
├── models/                      # 資料模型 (Data Models)
│   ├── user_model.dart          # 支援 joinedRoomIds, lastActiveRoomId
│   ├── room_model.dart          # 核心空間模型 (個人/群組)
│   ├── transaction_model.dart
│   ├── goal_model.dart
│   └── contribution_model.dart
│
├── services/                    # 低階服務層 (Low-level Services)
│   └── firestore_service.dart   # Firestore CRUD 操作 (使用 rooms 集合)
│
├── repositories/                # 業務邏輯層 (Business Logic)
│   ├── auth_repository.dart
│   ├── room_repository.dart     # 替代 couple_repository
│   ├── transaction_repository.dart
│   └── goal_repository.dart
│
├── providers/                   # 狀態管理 (State Management)
│   ├── auth_provider.dart
│   ├── room_provider.dart       # 替代 couple_provider
│   ├── joint_pot_provider.dart
│   ├── transaction_provider.dart
│   └── goal_provider.dart
│
├── screens/                     # 頁面
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── onboarding/
│   │   ├── create_room_screen.dart
│   │   └── join_room_screen.dart
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   └── goals/
│       └── goals_screen.dart
│
└── widgets/                     # 可重用元件
    ├── transaction_list_item.dart
    ├── goal_card.dart
    └── balance_card.dart
```

## 🛠️ Architecture Layers

### 0. **Core Mandate: Offline-First & Optimistic Updates**
- **Principle**: UI MUST update immediately upon user action. Do not wait for server response.
- **Implementation**:
  - **Client-Side IDs**: All models must use `Uuid().v4()` for IDs before sending to Firestore.
  - **Sync State**: Models should include an `isSyncing` flag (default true) to indicate local-only status.
  - **Event Sourcing**: Prefer syncing atomic "Events" (Transactions) rather than absolute "States" (Balances) to avoid conflicts.
  - **Persistence**: Firestore offline persistence must be enabled in `main.dart`.

### 1. **Models Layer** (`lib/models/`)
- **用途**: 定義資料結構，對應 Firestore 的文件格式
- **特點**: 
  - `fromMap()`: 從 Firestore Map 建立物件
  - `toMap()`: 轉換為 Firestore Map
  - `copyWith()`: Immutable 更新模式

### 2. **Services Layer** (`lib/services/`)
- **用途**: 封裝所有 Firestore 的低階操作
- **特點**: 
  - 不包含業務邏輯
  - 只負責 CRUD 操作
  - 類似 C++ 的 DAO (Data Access Object)

### 3. **Repositories Layer** (`lib/repositories/`)
- **用途**: 實作業務邏輯，協調多個 Service
- **特點**:
  - 處理複雜的業務規則 (例如：新增交易時同時更新餘額)
  - 驗證資料完整性
  - 類似 C++ 的 Service 層

### 4. **Providers Layer** (`lib/providers/`)
- **用途**: 使用 Provider 模式管理 UI 狀態
- **特點**:
  - 繼承 `ChangeNotifier`
  - 透過 `notifyListeners()` 通知 UI 更新
  - 類似 C++ 的 Observer Pattern 或 Singleton

## 🔄 Data Flow

```
UI (Widget)
    ↓
Provider (State Management)
    ↓
Repository (Business Logic)
    ↓
Service (Data Access)
    ↓
Firestore
```

## 📊 Firestore Schema

### Collections:
1. **users** - 使用者資料
   - `uid` (document ID)
   - `name`, `email`, `joined_room_ids` (array), `last_active_room_id`

2. **rooms** - 空間 (個人或群組)
   - `id` (document ID)
   - `name` (string)
   - `user_ids` (array)
   - `total_balance` (map: {uid: amount})
   - `invite_code` (6-digit string)
   - `type` (personal | group)
   - **Sub-collections:**
     - `transactions/` - 交易紀錄 (支出)
     - `savings_transactions/` - 公基金交易 (存入/領取)
     - `goals/` - 儲蓄目標
       - `contributions/` - 存入紀錄

## 🚀 Next Steps

1. **實作 Authentication & Onboarding Screens**
   - Login/Signup 頁面
   - 建立/加入 Room 頁面

2. **實作 Dashboard**
   - 顯示淨餘額 (Net Balance)
   - 交易列表 (使用 StreamBuilder)

3. **實作 Goals Feature**
   - 建立/編輯儲蓄目標
   - 進度條 UI
   - 快速存入功能

4. **整合 Provider 到 main.dart**
   - 使用 `MultiProvider` 包裝整個 App

## 💡 C++ Developer Notes

- **Models**: 類似 C++ 的 `struct` 或 `class`，但使用 Immutable Pattern
- **Repositories**: 類似 C++ 的 Service 類別，封裝業務邏輯
- **Providers**: 類似 C++ 的 Singleton + Observer Pattern
- **StreamBuilder**: 類似 C++ 的 Reactive Programming (RxCpp)
