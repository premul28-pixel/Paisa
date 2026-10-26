# 💰 PAISA – Offline Personal Finance Management

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/State_Management-Riverpod_2.5-0D47A1?style=for-the-badge)](https://riverpod.dev)
[![SQLite](https://img.shields.io/badge/Database-SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)
[![Security](https://img.shields.io/badge/Security-Offline_First_&_Encrypted-10B981?style=for-the-badge)]()

**PAISA** is a feature-rich, privacy-focused, offline-first personal finance management application built with Flutter. It enables users to take full control of their financial life with zero data tracking, zero third-party cloud vulnerabilities, and robust local encryption.

---

## 🔒 Security & Privacy Highlights

- **100% Offline-First Architecture**: Your financial data never leaves your device without your explicit export command.
- **SHA-256 Hashing**: User authentication credentials and recovery PINs are locally encrypted and secured using cryptographic hashing.
- **Zero API Secret Leakage**: Strict security rules and git exclusions ensure no environment variables, local properties, signing keys, or API tokens are tracked in version control.
- **Local SQLite Storage**: Fast, persistent, ACID-compliant local database.

---

## 🚀 Key Features

- **Dashboard & Analytics**:
  - Net balance, total income, and total expense overviews.
  - Interactive financial charts and spending breakdowns powered by `fl_chart`.
  - Transaction history filtering (Day, Month, Year, Custom ranges).

- **Income & Expense Management**:
  - Categorized spending (Food, Transport, Shopping, Bills, Healthcare, Entertainment, etc.).
  - Multi-source income tracking (Salary, Freelance, Business, Investments, Gifts, etc.).
  - Wallet assignment (Cash, UPI, Bank).

- **Wallet System**:
  - Real-time balance calculations across multiple payment channels.
  - Instant balance updates upon recording transactions.

- **Reports, Exports & Backups**:
  - Export complete transaction histories to **CSV**.
  - Generate and print beautifully styled **PDF Financial Statements**.
  - Create and restore full encrypted JSON backup snapshots of all user data.

- **UI / UX**:
  - Built with Material 3 design principles.
  - Seamless Light and Dark mode support with customized emerald & slate color palettes.

---

## 🛠️ Tech Stack & Dependencies

| Dependency | Purpose |
|---|---|
| `flutter_riverpod` | Reactive, compile-safe state management |
| `sqflite` & `path` | Local SQLite database persistence |
| `fl_chart` | Interactive charts and graphical financial insights |
| `csv` | Exporting transaction logs to CSV format |
| `pdf` & `printing` | Generating and printing PDF financial statements |
| `crypto` | SHA-256 encryption for passwords and PIN validation |
| `intl` | Date, currency, and number formatting |

---

## 💻 Getting Started

### Prerequisites

- Flutter SDK `>= 3.0.0`
- Android SDK or iOS toolchain installed

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/premul28-pixel/Paisa.git
   cd Paisa
   ```

2. **Configure Environment (if extending with external APIs):**
   ```bash
   cp .env.example .env
   ```
   *(Configure your API keys in `.env`. Note: `.env` is git-ignored for safety).*

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run the application:**
   ```bash
   flutter run
   ```

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/       # App-wide constants, categories, wallets
│   ├── database/        # SQLite schema constants & table definitions
│   ├── theme/           # Light & Dark Material 3 theme configurations
│   └── utils/           # Date formatters and helper utilities
├── models/              # Immutable data models (User, Wallet, Transaction, Settings)
├── providers/           # Riverpod state providers
├── repositories/        # Repository layer abstracting database operations
├── screens/             # UI views (Auth, Dashboard, Income, Expense, Reports, Settings)
├── services/            # SQLite, Export (CSV/PDF), Backup & Restore services
└── widgets/             # Reusable UI components
```

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
