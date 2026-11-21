<div align="center">

# ⚡ QuickTick (QuickLink)
### Next-Generation Hyperlocal Quick-Commerce & AI-Powered Grocery Ecosystem

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Architecture%20%2B%20BLoC-blue)](https://bloclibrary.dev)
[![AI RAG](https://img.shields.io/badge/AI-Groq%20Vision%20%2B%20Catalog%20RAG-orange)](https://groq.com)
[![Payments](https://img.shields.io/badge/Payments-Razorpay%20Live%20%2B%20Dynamic%20QR-0C2340?logo=razorpay&logoColor=white)](https://razorpay.com)
[![WebSockets](https://img.shields.io/badge/RealTime-Socket.io%20Live%20Telemetry-010101?logo=socketdotio&logoColor=white)](https://socket.io)
[![License](https://img.shields.io/badge/License-Proprietary-red)](#)

*An enterprise-grade, multi-tenant quick-commerce platform delivering instant groceries and essentials in minutes. Built with Flutter, Clean Architecture, BLoC state management, real-time bi-directional WebSockets, and Multimodal AI-driven Handwritten List RAG.*

---

[Key Highlights](#-key-architectural-highlights) • 
[System Design](#-enterprise-system-design--clean-architecture) • 
[AI Handwritten RAG](#-ai-vision--handwritten-list-rag-pipeline) • 
[Tech Stack](#-technical-stack--dependencies) • 
[Security & Payments](#-payment-gateway--security-engineering) • 
[Testing Suite](#-testing-strategy--qa) • 
[Setup Guide](#-getting-started--environment-setup)

</div>

---

## 🌟 Executive Summary

**QuickTick** is a production-hardened hyperlocal quick-commerce ecosystem engineered to handle the complete end-to-end lifecycle of on-demand retail: from consumer catalog browsing and instant checkout, to merchant kitchen/shelf fulfillment, through real-time GPS delivery dispatch.

The codebase implements a unified **multi-flavor monorepo** architecture supporting three distinct user personas within a single codebase:
1. **Customer App (`--flavor customer`)**: Consumer catalog discovery, category hierarchy, cart math & promo engines, AI paper-list scanner, live order timeline, and digital tax invoices.
2. **Retailer App (`--flavor retailer`)**: Store-side order manager with sound buzzer alerts, stock toggling, category-level KYC compliance upload, and financial settlement analytics.
3. **Delivery Partner App (`--flavor delivery`)**: Live dispatching, route guidance, status step progression, doorstep dynamic UPI QR generation, and proof-of-delivery OTP validation.

---

## 🏗️ Enterprise System Design & Clean Architecture

The platform strictly adheres to **Uncle Bob's Clean Architecture** and **SOLID principles**, enforcing unidirectional data flow and complete decoupling of business logic from UI widgets and third-party frameworks.

```
lib/
├── core/                                # Shared Infrastructure & Cross-Cutting Concerns
│   ├── ai/                              # Groq Vision Client & Catalog RAG Engine
│   ├── network/                         # Dio HTTP Client, Refresh Token Mutex & ApiEndpoints
│   ├── security/                        # FlutterSecureStorage (Encrypted Keystore/Keyring)
│   ├── services/                        # Razorpay Payment Services & Audio Alert Buzzers
│   ├── theme/                           # QuickTick Design System (Typography, Radii, Palette)
│   └── websockets/                      # Socket.io Service with Exponential Backoff & Room Isolation
│
├── features/                            # Domain-Driven Slices
│   ├── customer/                        # Catalog, Nearby Stores, Cart, Search
│   ├── retailer/                        # Order Management, Document Verification, Inventory
│   ├── delivery/                        # Route Telemetry, Dispatch Acceptance, Doorstep QR
│   ├── order/                           # Order State Machine, Cancellation, Invoicing
│   └── ai_assistant/                    # Conversational Agent & Handwritten OCR Extraction
│       │
│       ├── domain/                      # Enterprise Business Rules (Pure Dart - 0 Flutter dependencies)
│       │   ├── entities/                # Core Data Models & Immutable Values
│       │   └── repositories/            # Repository Contracts & Interfaces
│       │
│       ├── data/                        # Interface Adapters
│       │   ├── datasources/             # Remote REST / Sockets / Secure Storage Data Sources
│       │   ├── models/                  # JSON Serialization & Entity Mappers
│       │   └── repositories/            # Concrete Repository Implementations & Cache Pruning
│       │
│       └── presentation/                # Frameworks & UI
│           ├── bloc/                    # Business Logic Components (Events, States, Transitions)
│           ├── screens/                 # Responsive Scaffold Views & Bottom Navigation
│           └── widgets/                 # Reusable UI Primitives, Sheets & Atomic Elements
```

### Key Architectural Strengths:
* **Decoupled Domain Layer**: Pure Dart entities and abstract repository contracts ensure zero framework lock-in and 100% testability.
* **BLoC Reactive State Machine**: Predictable, immutable state management using `flutter_bloc` with discrete events, preventing race conditions and UI re-render thrashing.
* **Token Mutex Concurrency**: Custom Dio interceptor with a mutex queue ensures that simultaneous 401 unauthorized responses wait on a single cryptographic token refresh rather than triggering duplicate network requests.
* **Authoritative Cache Reconciliation**: Stale client-generated fallback items are automatically pruned in favor of authoritative remote server state, eliminating ghost orders.

---

## 🤖 AI Vision & Handwritten List RAG Pipeline

One of QuickTick’s standout features is the **Multimodal Handwritten Grocery List RAG (Retrieval-Augmented Generation)** service.

### The Problem:
Shoppers frequently maintain handwritten grocery lists on scrap paper using colloquial, abbreviated, or regional product names (e.g., *"atta 5kg"*, *"amul taaza"*, *"dettol bada"*). Standard OCR tools fail because handwritten notes lack standardized formatting, and raw text cannot map to specific SKUs.

### The Solution:
```mermaid
flowchart LR
    A[Camera / Gallery Image] --> B[Base64 Encoding & Validation]
    B --> C[Groq LLaMA 3.3 Multimodal Vision Model]
    C --> D[Structured JSON Parsing: Item, Qty, Unit]
    D --> E[In-Memory Catalog Vector Search & Fuzzy Matcher]
    E --> F[Availability & Stock Guard]
    F --> G[Interactive Match Sheet with Live Prices]
    G --> H[One-Tap Batch Cart Addition]
```

1. **Vision Inference**: High-speed multimodal LLM (`llama-3.3-70b-versatile` / vision) extracts raw items, units, and quantities with confidence scoring.
2. **Context-Aware Semantic Retrieval (RAG)**: The extracted items are normalized and matched against the live store catalog using Levenshtein distance and token-overlap scoring.
3. **Inventory & Price Validation**: Each candidate is verified for live stock status, unit pricing, and store availability before presenting the customer with a one-tap review and add-to-cart sheet.

---

## 💳 Payment Gateway & Security Engineering

* **Razorpay Production Integration**: Native Android & iOS SDK checkout sheets with cryptographically verified HMAC SHA-256 signatures on the backend.
* **Direct Order Fallback UI**: In case of transient native gateway timeouts, a custom `RazorpayCheckoutSheet` surfaces with official Razorpay brand styling to prevent checkout abandonment.
* **Doorstep Dynamic UPI QR**: Generates dynamic NPCI-compliant UPI transaction strings (`upi://pay?pa=...&am=...&tr=...`) for instant contactless COD verification by delivery executives.
* **Environment Secret Scrubbing**: Zero hardcoded API keys or secrets in source tracking. Production keys are injected at compile time via `--dart-define` or `.env` files protected by `.gitignore`.

---

## ⚡ Real-Time Socket Architecture

```
[Customer Client] <──────┐
                         ├───> [Socket.io Cluster] <───> [MongoDB ChangeStreams]
[Retailer Client] <──────┤
[Delivery Agent]  <──────┘
```

* **Room-Based Message Routing**: Clients subscribe to dedicated scoped channels (`order:${id}`, `store:${id}`, `courier:${id}`).
* **Order Status Transition Machine**:
  $$\text{PLACED} \longrightarrow \text{ACCEPTED} \longrightarrow \text{PREPARING} \longrightarrow \text{OUT\_FOR\_DELIVERY} \longrightarrow \text{DELIVERED}$$
* **Instant Cancellation Protocols**: Validates MongoDB ObjectIds (`24-character hexadecimal`) before dispatching cancel requests to the backend server to prevent client-server schema mismatch.
* **Failover Resilience**: In the event of network disruption, the client gracefully falls back to cached SQLite/in-memory states and resynchronizes via REST upon reconnect.

---

## 🧪 Testing Strategy & QA

The repository includes a comprehensive, production-grade test suite covering domain logic, UI widgets, and integration flows:

```bash
flutter test
```

### Test Coverage Highlights:
| Test Suite | Focus Area | Verification |
| :--- | :--- | :--- |
| `customer_production_flow_test.dart` | Order Cancellation, Invoice Downloads, Cart Math | Positive, 404 remote handling & boundaries |
| `handwritten_list_rag_test.dart` | AI Vision RAG, Fuzzy Matcher, Batch Cart Add | Item mapping, quantity increment/decrement |
| `razorpay_live_key_test.dart` | Secret Sanitization & Gateway Key Parsing | Key parsing, amount in paise conversion |
| `invoice_download_test.dart` | Vector PDF Generator & Backend 404 Fallback | Tax breakdown, GSTIN snapshots, PDF 1.4 specs |
| `retailer_comprehensive_test.dart` | Audio Buzzers, Stock Toggling, Settlements | Order acceptance, sound playback trigger |
| `delivery_flow_end_to_end_test.dart` | Route Navigation, Doorstep QR, POD OTP | GPS coordinates, QR rendering, OTP dispatch |

---

## 🛠️ Technical Stack & Dependencies

| Layer | Technologies |
| :--- | :--- |
| **Framework** | Flutter 3.x (Dart 3.x) |
| **State Management** | `flutter_bloc` (v8.x), `equatable` |
| **Network & APIs** | `dio` (v5.x), `http`, `socket_io_client` |
| **Local Storage** | `flutter_secure_storage`, `shared_preferences` |
| **AI & Multimodal** | Groq Cloud API (`llama-3.3-70b-versatile` / Vision) |
| **Payments** | `razorpay_flutter`, `qr_flutter` |
| **Media & Audio** | `audioplayers`, `image_picker`, `pdf`, `printing` |
| **CI / CD & Tooling** | Shorebird (CodePush updates), Android Flavors, ProGuard |

---

## 🚀 Getting Started & Environment Setup

### 1. Prerequisites
* Flutter SDK: `>= 3.24.0`
* Android Studio / Xcode with Android SDK & CocoaPods
* Node.js & Git

### 2. Clone the Repository
```bash
git clone https://github.com/chetanshetty326/quicktick.git
cd quicktick
```

### 3. Configure Secrets
Copy the environment template and populate your local keys:
```bash
cp .env.example .env
```
Edit `.env`:
```env
GROQ_API_KEY=your_groq_api_key_here
RAZORPAY_KEY_ID=your_razorpay_key_id_here
```

### 4. Install Dependencies
```bash
flutter pub get
```

### 5. Running the Apps by Flavor
To launch a specific persona in debug or release mode:

```bash
# Customer Application
flutter run --flavor customer -t lib/main_customer.dart --dart-define-from-file=.env

# Retailer Partner Application
flutter run --flavor retailer -t lib/main_retailer.dart --dart-define-from-file=.env

# Delivery Executive Application
flutter run --flavor delivery -t lib/main_delivery.dart --dart-define-from-file=.env
```

### 6. Building Production Release APKs
```bash
# Build Customer Release APK
flutter build apk --flavor customer -t lib/main_customer.dart --release --dart-define-from-file=.env
```

---

## 👨‍💻 Engineering Philosophy & Highlights for Interviewers

* **Production-First Mindset**: Built with zero reliance on dummy mock data; resilient fallback pipelines handle live server outages, holiday zone closures, and slow networks gracefully.
* **Separation of Concerns**: UI widgets never talk directly to HTTP clients or perform JSON deserialization. Everything flows strictly through BLoC events and repository abstractions.
* **Security & Secret Hygiene**: Production secrets are never committed to version control. Keys are injected via environment files and guarded with `.gitignore`.
* **Real-World Innovation**: Integrates generative AI (Groq Vision LLMs) with practical e-commerce (Catalog RAG) to solve real customer friction in grocery ordering.

---

<div align="center">
  <sub>Engineered with precision by <b>Chetan Shetty</b>. Built for speed, scalability, and seamless user experiences.</sub>
</div>
