# Couples Finance App - Architecture Overview

## 📁 Folder Structure

```
lib/
├── main.dart                    # App 入口，Firebase 初始化
├── firebase_options.dart        # Firebase 設定檔
│
├── models/                      # 資料模型 (Data Models)
│   ├── user_model.dart
│   ├── couple_model.dart
│   ├── transaction_model.dart
│   ├── goal_model.dart
│   └── contribution_model.dart
│
├── services/                    # 低階服務層 (Low-level Services)
│   └── firestore_service.dart   # Firestore CRUD 操作
│
├── repositories/                # 業務邏輯層 (Business Logic)
│   ├── auth_repository.dart
│   ├── couple_repository.dart
│   ├── transaction_repository.dart
│   └── goal_repository.dart
│
├── providers/                   # 狀態管理 (State Management)
│   ├── auth_provider.dart
│   ├── couple_provider.dart
│   ├── transaction_provider.dart
│   └── goal_provider.dart
│
├── screens/                     # 頁面 (待實作)
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── onboarding/
│   │   ├── create_couple_screen.dart
│   │   └── join_couple_screen.dart
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   └── goals/
│       └── goals_screen.dart
│
└── widgets/                     # 可重用元件 (待實作)
    ├── transaction_list_item.dart
    ├── goal_card.dart
    └── balance_card.dart
```

## 🏗️ Architecture Layers

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
   - `name`, `email`, `current_couple_id`

2. **couples** - 情侶配對
   - `id` (document ID)
   - `user_ids` (array)
   - `total_balance` (map: {uid: amount})
   - `invite_code` (6-digit string)
   - **Sub-collections:**
     - `transactions/` - 交易紀錄
     - `goals/` - 儲蓄目標
       - `contributions/` - 存入紀錄

## 🚀 Next Steps

1. **實作 Authentication & Onboarding Screens**
   - Login/Signup 頁面
   - 建立/加入 Couple Space 頁面

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
