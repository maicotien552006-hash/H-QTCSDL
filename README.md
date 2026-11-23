<div align="center">

# 🛒 OISM - OMNICHANNEL INVENTORY & SALES MANAGEMENT SYSTEM
### Hệ Thống Quản Lý Bán Hàng & Tồn Kho Đa Kênh Chuẩn Enterprise

[![SQL Server 2022](https://img.shields.io/badge/SQL%20Server%202022-v16.0%20(Compat%20160)-CC292B?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/sql-server)
[![.NET 8.0](https://img.shields.io/badge/.NET-8.0%20Minimal%20API-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose%20Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/maicotien552006-hash/H-QTCSDL/actions)
[![Architecture](https://img.shields.io/badge/Architecture-Multi--Tenant%20%7C%20ACID-success?style=for-the-badge)](#-2-kiến-trúc-hệ-thống)

<p align="center">
  <b>Đồ Án Môn Học:</b> Hệ Quản Trị Cơ Sở Dữ Liệu (H-QTCSDL)<br/>
  <b>Kho lưu trữ:</b> <a href="https://github.com/maicotien552006-hash/H-QTCSDL">github.com/maicotien552006-hash/H-QTCSDL</a>
</p>

[✨ Giới Thiệu](#-1-tổng-quan-dự-án) •
[🏛️ Kiến Trúc](#-2-kiến-trúc-hệ-thống) •
[💎 8 Kỹ Thuật CSDL Cốt Lõi](#-3-bảng-8-kỹ-thuật-csdl-sql-server-2022-nâng-cao) •
[🗺️ Mô Hình Dữ Liệu](#-4-mô-hình-thực-thể-erd--cơ-sở-dữ-liệu) •
[🚀 Hướng Dẫn Khởi Chạy](#-5-hướng-dẫn-cài-đặt--khởi-chạy) •
[🔑 Tài Khoản Demo](#-6-ma-trận-tài-khoản--phân-quyền-rbac) •
[🎯 Kịch Bản Bảo Vệ](#-7-kịch-bản-5-bước-trình-diễn-chấm-thi) •
[📡 API Reference](#-8-danh-mục-api-endpoints) •
[🛠️ Khắc Phục Sự Cố](#-9-khắc-phục-sự-cố-thường-gặp)

---

</div>

## 📖 1. Tổng Quan Dự Án

**OISM** là giải pháp phần mềm quản trị bán lẻ và tồn kho đa kênh thời gian thực (Omnichannel), kết nối đồng bộ giữa các quầy thu ngân vật lý (POS) với các sàn thương mại điện tử hàng đầu (Shopee, TikTok Shop, Lazada).

Hệ thống được xây dựng tập trung làm nổi bật **sức mạnh của Hệ Quản Trị CSDL Microsoft SQL Server 2022** trong việc giải quyết các bài toán kỹ thuật phức tạp:
- ⚡ **Chống bán âm (Anti-oversell) khi Flash Sale:** Kiểm soát tương tranh bi quan (`UPDLOCK`, `ROWLOCK`) và xử lý giao dịch ACID nguyên tử.
- 🔒 **Cô lập dữ liệu Đa người thuê (Multi-Tenancy):** Bảo vệ dữ liệu bằng Row-Level Security (RLS) ngay tại nhân CSDL mà không phụ thuộc tầng ứng dụng.
- 📜 **Sổ cái kho bất biến (Append-Only Ledger):** Ngăn chặn gian lận, truy vết 100% lịch sử biến động kho theo nguyên tắc kế toán kép.
- 📊 **Xử lý phân tích dữ liệu lớn (Real-Time Analytics):** Nonclustered Columnstore Index và Phân vùng bảng (Partitioning) tăng tốc độ báo cáo gấp hàng chục lần.

---

## 🏛️ 2. Kiến Trúc Hệ Thống

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                                 TẦNG TRÌNH DIỄN                                  │
│  Single-Page Application (HTML5, Tailwind CSS, Heroicons, Leaflet GIS, Audio FX) │
│  - Màn hình Bán hàng POS Fast-Checkout (Phím tắt F1-F12, Quét Barcode EAN-13)   │
│  - Mô phỏng Webhook sàn TMĐT (Shopee/TikTok Flash Sale Concurrency 50 threads)   │
│  - Bản đồ GPS tương tác trực quan định vị Chi nhánh & Kho hàng WGS84             │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │  (HTTP / JSON RESTful API)
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                                 TẦNG NGHIỆP VỤ                                   │
│            Backend ASP.NET Core 8.0 Web API (High-Performance Minimal API)       │
│  - Xác thực & Phân quyền: JWT Authentication + Role-Based Access Control (RBAC)  │
│  - Ngữ cảnh phiên: sp_set_session_context @TenantId kích hoạt bộ lọc bảo mật RLS│
│  - Truy cập dữ liệu: Micro-ORM Dapper tối ưu hóa I/O, giảm thiểu overhead EF    │
│  - Nền tảng tự động: Background Worker quét & hoàn trả tồn kho giữ quá hạn       │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │  (T-SQL Procedures, Triggers, Views)
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             TẦNG CƠ SỞ DỮ LIỆU                                   │
│              Microsoft SQL Server 2022 Enterprise (Compat Level 160)             │
│  ┌───────────────────────┬─────────────────────────┬──────────────────────────┐  │
│  │ RCSI Isolation        │ Row-Level Security(RLS) │ Temporal System-Versioned│  │
│  ├───────────────────────┼─────────────────────────┼──────────────────────────┤  │
│  │ Spatial GIS (SRID4326)│ Columnstore Index (NCCI)│ Table Partitioning       │  │
│  ├───────────────────────┴─────────────────────────┴──────────────────────────┤  │
│  │ Triggers nghiệp vụ: Immutable Ledger (Append-Only) & Giá vốn bình quân WAC │  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 💎 3. Bảng 8 Kỹ Thuật CSDL SQL Server 2022 Nâng Cao

Hệ thống hiện thực hóa trọn vẹn 8 chuyên đề trọng tâm của môn học **Hệ Quản Trị CSDL**:

| # | Kỹ Thuật SQL Server 2022 | Đối Tượng / Cú Pháp Minh Họa | Cơ Chế Hoạt Động & Nghiệp Vụ Trong OISM |
| :-: | :--- | :--- | :--- |
| **1** | **RCSI (Read Committed Snapshot)** | `ALTER DATABASE OISM SET READ_COMMITTED_SNAPSHOT ON` | Sử dụng hàng phiên bản (Row Versioning) trong `tempdb`. Người đọc (Thu ngân tra tồn kho) không chặn người ghi (Thủ kho nhập hàng) và ngược lại $\rightarrow$ **Xóa bỏ hoàn toàn hiện tượng Deadlock** lúc cao điểm. |
| **2** | **Row-Level Security (RLS)** | `sec.fn_TenantSecurityPredicate`<br>`sec.TenantIsolationPolicy` | Hàm vị từ bảo mật kiểm tra `SESSION_CONTEXT(N'TenantId')`. Ngăn chặn triệt để rò rỉ dữ liệu giữa các chuỗi cửa hàng ngay tại tầng Database Engine mà không cần mệnh đề `WHERE TenantId = @id` ở backend. |
| **3** | **Temporal Tables (System-Versioned)** | `dbo.ListedPrices`<br>`dbo.ListedPricesHistory` | Tự động ghi lại dòng thời gian hiệu lực (`ValidFrom`, `ValidTo`) theo chuẩn ISO-8601. Cho phép truy vấn lại chính xác bảng giá tại bất kỳ thời điểm nào trong quá khứ (`FOR SYSTEM_TIME AS OF ...`). |
| **4** | **Spatial GIS (SRID 4326)** | `dbo.Branches.Location` (`geography`)<br>`Location.STDistance(@ClientLoc)` | Lưu trữ vị trí kinh độ/vĩ độ (Ellipsoid WGS84). Tính toán khoảng cách địa lý theo đơn vị mét (Great-Circle Distance) để tự động chọn chi nhánh tối ưu giao hàng. |
| **5** | **Nonclustered Columnstore Index (NCCI)** | `NCCI_OrderItems_Analytics`<br>trên `dbo.OrderItems` | Nén dữ liệu theo từng cột với tỷ lệ nén 5x-10x. Tăng tốc độ tính toán tổng doanh thu, lợi nhuận gộp và sản lượng bán gấp 10-100 lần so với B-Tree truyền thống. |
| **6** | **Table Partitioning (Phân Vùng Bảng)** | `pf_Ledger_Monthly` (Function)<br>`ps_Ledger_Monthly` (Scheme) | Tách vật lý dữ liệu bảng `dbo.InventoryLedger` thành các phân vùng độc lập theo từng tháng giao dịch. Giúp việc bảo trì, lưu trữ và rà soát sổ cái lịch sử đạt hiệu năng tối đa. |
| **7** | **Append-Only Ledger Trigger** | `trg_InventoryLedger_AppendOnly`<br>trên `dbo.InventoryLedger` | Chặn đứng 100% mọi thao tác `UPDATE` và `DELETE`. Nếu có sửa chữa tồn kho, nhân viên bắt buộc phải tạo bút toán điều chỉnh mới (`Type='ADJUST'`), đảm bảo tính toàn vẹn kế toán. |
| **8** | **Weighted Average Cost (WAC) Trigger** | `trg_PurchaseReceiptItems_WeightedAvgCost`<br>trên `dbo.PurchaseReceiptItems` | Tự động tính toán lại giá vốn bình quân gia quyền của SKU ngay khi phiếu nhập kho được chốt: `NewCost = (OldQty * OldCost + InQty * InCost) / (OldQty + InQty)`. |

<details>
<summary><b>🔍 Nhấp vào đây để xem chi tiết mã T-SQL của các kỹ thuật trên</b></summary>

```sql
-- 1. Kích hoạt RCSI
ALTER DATABASE OISM SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;

-- 2. Hàm vị từ RLS
CREATE FUNCTION sec.fn_TenantSecurityPredicate(@TenantId INT)
RETURNS TABLE WITH SCHEMABINDING AS
RETURN SELECT 1 AS fn_result
WHERE @TenantId = CAST(SESSION_CONTEXT(N'TenantId') AS INT);

-- 3. Bảng Temporal theo dõi biến động giá
CREATE TABLE dbo.ListedPrices (
    PriceId INT IDENTITY PRIMARY KEY,
    TenantId INT NOT NULL,
    SKUId INT NOT NULL,
    RetailPrice DECIMAL(18,2) NOT NULL,
    WholesalePrice DECIMAL(18,2) NOT NULL,
    ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ListedPricesHistory));

-- 4. Nonclustered Columnstore Index
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_OrderItems_Analytics
ON dbo.OrderItems (TenantId, SKUId, Quantity, UnitPrice, CostPrice, SubTotal);

-- 5. Trigger bảo vệ Sổ cái bất biến
CREATE TRIGGER trg_InventoryLedger_AppendOnly ON dbo.InventoryLedger
AFTER UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    RAISERROR(N'VI PHẠM NGUYÊN TẮC KẾ TOÁN: Bảng InventoryLedger là sổ cái Append-only, cấm tuyệt đối UPDATE/DELETE!', 16, 1);
    ROLLBACK TRANSACTION;
END;
```
</details>

---

## 🗺️ 4. Mô Hình Thực Thể ERD & Cơ Sở Dữ Liệu

Hệ thống CSDL được chuẩn hóa ở dạng chuẩn 3NF kết hợp với các kỹ thuật vật lý nâng cao:

```
[Tenants] (Cửa hàng / Chuỗi)
   │
   ├──< [Users] (Tài khoản & Phân quyền RBAC)
   ├──< [Branches] (Chi nhánh & Tọa độ GIS Location)
   │       │
   │       └──< [Inventories] (Tồn kho vật lý: OnHand, Reserved)
   │                 │
   │                 └──< [InventoryLedger] (Sổ cái xuất/nhập/điều chỉnh - Partitioned)
   │
   ├──< [Categories] (Danh mục cây phân cấp ParentId)
   ├──< [Brands] (Thương hiệu)
   └──< [Products] (Sản phẩm)
           │
           └──< [SKUs] (Mã biến thể SKU, Barcode EAN-13, Giá vốn WAC)
                   │
                   ├──< [ListedPrices] (Bảng giá niêm yết - Temporal Table)
                   └──< [OrderItems] (Chi tiết đơn hàng - Columnstore Index)
                           ▲
                           │
                   [Orders] (Đơn hàng đa kênh: POS, Shopee, TikTok, Lazada)
```

---

## 📂 5. Cấu Trúc Dự Án

```
oism-web/
├── .github/workflows/ci-cd.yml      # CI/CD Pipeline (MSSQL 2022 Test + .NET Build + Docker)
├── backend/                         # Backend Web API
│   ├── Program.cs                   # Endpoints, JWT Auth, RLS SessionContext, Concurrency Logic
│   ├── appsettings.json             # Chuỗi kết nối SQL Server & Secret Token
│   ├── backend.csproj               # .NET 8, Dapper, Microsoft.Data.SqlClient
│   └── Dockerfile                   # Dockerfile Backend
├── scripts/init-db.sh               # Shell script tự động khởi tạo DB trong Docker
├── SQLQuery1.sql                    # Script DDL Schema, RLS, Indexes, Procedures, Triggers
├── OISM_User_Accounts.sql           # Danh sách tài khoản mẫu theo vai trò
├── OISM_Spatial_GPS_Demo.sql        # Dữ liệu GPS chi nhánh tại TP.HCM & Hà Nội
├── index.html                       # Frontend Single-Page POS & Admin Dashboard
├── docker-compose.yml               # File điều phối 4 container (DB, Seeder, API, Web)
├── docker-start.bat                 # Script 1-click khởi chạy bằng Docker
├── start.bat                        # Script khởi chạy Backend cục bộ với SSMS
├── push_to_github.bat               # Script đẩy mã nguồn lên GitHub
├── nginx.conf                       # Cấu hình Web Server Nginx
├── Dockerfile.frontend              # Dockerfile Frontend
├── BAO_CAO_CAC_YEU_CAU_CON_THIEU_OISM.md # Báo cáo phân tích đối soát đồ án
└── README.md                        # Tài liệu hướng dẫn sử dụng chi tiết
```

---

## 🚀 6. Hướng Dẫn Cài Đặt & Khởi Chạy

Bạn có thể lựa chọn 1 trong 3 phương pháp khởi chạy tùy thuộc vào môi trường máy tính:

### 🌟 Cách 1: Khởi Chạy Tự Động Bằng Docker (Khuyên dùng - Nhanh nhất)
> *Không yêu cầu cài đặt .NET SDK hay SQL Server.*

1. Khởi động ứng dụng **Docker Desktop**.
2. Nhấp đúp vào file **`docker-start.bat`** (hoặc mở Terminal tại thư mục này):
   ```bash
   docker compose up -d --build
   ```
3. Chờ 15-20 giây để hệ thống tự động khởi tạo container, chạy seed dữ liệu CSDL.
4. Truy cập hệ thống:
   * **Giao diện Web App:** [http://localhost:8080](http://localhost:8080)
   * **Kiểm tra API Health:** [http://localhost:5000/api/health](http://localhost:5000/api/health)
   * **Kết nối SQL Server 2022:** `localhost,1433` *(User: `sa` | Password: `Oism2026@StrongPassword!`)*

---

### 💻 Cách 2: Khởi Chạy Thủ Công Với SQL Server Management Studio (SSMS)
> *Dành cho việc chấm điểm trực tiếp, đặt breakpoint và debug T-SQL.*

1. Mở **SSMS**, kết nối tới instance SQL Server 2022 trên máy bạn.
2. Mở file **`SQLQuery1.sql`** và nhấn **F5** để tạo Database `OISM`, các bảng, RLS, Indexes, Procedures và Triggers.
3. Mở và chạy tiếp **`OISM_User_Accounts.sql`** và **`OISM_Spatial_GPS_Demo.sql`** để nạp tài khoản và tọa độ GPS.
4. Nhấp đúp vào **`start.bat`**, chọn **[1]** để khởi động Backend API và tự động mở Web App.
5. Mọi thao tác xuất/nhập/bán hàng trên Web sẽ được ghi nhận và truy vấn trực tiếp trong SSMS theo thời gian thực!

---

### 🌐 Cách 3: Chế Độ Giả Lập In-Memory (Trực tiếp trên Trình duyệt)
> *Phù hợp khi trình chiếu trên máy chấm thi không có sẵn môi trường lập trình.*

* Nhấp đúp mở trực tiếp file **`index.html`** trên trình duyệt (Chrome, Edge, Firefox).
* Hệ thống sẽ tự động kích hoạt **In-Memory Engine** với dữ liệu mẫu hoàn chỉnh để thử nghiệm tính năng mà không phát sinh lỗi kết nối.

---

## 🔑 7. Ma Trận Tài Khoản & Phân Quyền (RBAC)

Dữ liệu được chuẩn bị sẵn cho **2 Tenant độc lập** nhằm kiểm chứng tính năng **Row-Level Security**:

| Tenant / Cửa Hàng | Email Đăng Nhập | Mật Khẩu | Vai Trò (Role) | Chức Năng Cho Phép |
| :--- | :--- | :---: | :---: | :--- |
| **Cửa hàng Thời trang Minh Anh** *(Tenant 1)* | `owner@minhanh.vn` | `123456` | **Owner** | Toàn quyền: Xem báo cáo tài chính, quản lý chi nhánh, sản phẩm, giá bán. |
| **Cửa hàng Thời trang Minh Anh** *(Tenant 1)* | `thungan@minhanh.vn` | `123456` | **Cashier** | Quầy bán hàng POS, quét barcode EAN-13, in hóa đơn thanh toán. Bị ẩn báo cáo tài chính. |
| **Cửa hàng Nông sản Hữu cơ Xanh** *(Tenant 2)* | `owner@nongsanxanh.vn` | `123456` | **Owner** | Quản trị cửa hàng nông sản. Tuyệt đối không nhìn thấy dữ liệu của Tenant 1. |
| **Cửa hàng Nông sản Hữu cơ Xanh** *(Tenant 2)* | `thukho@nongsanxanh.vn` | `123456` | **Warehouse** | Quản lý kho: Nhập kho NCC, xuất hủy, kiểm kê, kích hoạt trigger tính giá vốn WAC. |

---

## 🎯 8. Kịch Bản 5 Bước Trình Diễn Chấm Thi

Kịch bản được thiết kế bám sát yêu cầu chấm điểm của Giảng viên môn **Hệ Quản Trị CSDL**:

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│ Bước 1: Chứng minh Row-Level Security (RLS)                                    │
│ ├── Đăng nhập `owner@minhanh.vn` (Tenant 1) -> Xem danh sách sản phẩm.          │
│ ├── Đăng xuất, đăng nhập `owner@nongsanxanh.vn` (Tenant 2) -> Dữ liệu cách ly. │
│ └── Mở SSMS xem hàm vị từ `sec.fn_TenantSecurityPredicate`.                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│ Bước 2: Bán hàng POS & Bút toán Sổ cái tự động                                  │
│ ├── Vào POS chọn sản phẩm, nhấn F4 thanh toán tiền mặt.                         │
│ └── Mở SSMS chạy: SELECT TOP 5 * FROM dbo.InventoryLedger ORDER BY LedgerId DESC│
│     -> Chứng minh bút toán xuất kho Type='OUT', TxnType='Sale' sinh tức thì.    │
├─────────────────────────────────────────────────────────────────────────────────┤
│ Bước 3: Kiểm thử Tính Bất Biến của Sổ Cái (Append-Only Protection)             │
│ ├── Trong SSMS thực thi: DELETE FROM dbo.InventoryLedger;                       │
│ └── Kết quả: Trigger `trg_InventoryLedger_AppendOnly` chặn đứng và báo lỗi.     │
├─────────────────────────────────────────────────────────────────────────────────┤
│ Bước 4: Kiểm soát Tương tranh & Chống Bán Âm (Flash Sale Concurrency)           │
│ ├── Chọn sản phẩm FLASH-001 (chỉ còn đúng 1 tồn kho).                           │
│ ├── Nhấn nút "Chạy mô phỏng Flash Sale 50 luồng đồng thời".                     │
│ └── Kết quả: Đúng 1 đơn thành công, 49 đơn từ chối, tồn kho không bao giờ âm. │
├─────────────────────────────────────────────────────────────────────────────────┤
│ Bước 5: Bản đồ GPS Chi Nhánh & Temporal Table Biến Động Giá                     │
│ ├── Mở tab GIS, xem bản đồ Leaflet và hàm `STDistance` tìm shop gần nhất.       │
│ ├── Đổi giá niêm yết của 1 SKU trên Web.                                        │
│ └── Mở SSMS chạy: SELECT * FROM dbo.ListedPrices FOR SYSTEM_TIME ALL            │
│     -> Chứng minh toàn bộ lịch sử giá cũ được lưu trữ tự động.                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📡 9. Danh Mục API Endpoints

| Nhóm Chức Năng | Phương Thức | Endpoint URI | Mô Tả Nghiệp Vụ |
| :--- | :---: | :--- | :--- |
| **Xác thực** | `POST` | `/api/auth/login` | Đăng nhập, trả về JWT Token chứa `TenantId, Role` |
| **Xác thực** | `POST` | `/api/auth/register` | Đăng ký chuỗi cửa hàng Tenant mới |
| **Chi nhánh** | `GET` | `/api/branches` | Lấy danh sách chi nhánh (Kèm tọa độ GPS WGS84) |
| **Sản phẩm** | `GET` | `/api/products` | Danh sách sản phẩm & danh mục phân cấp |
| **Bán hàng POS** | `POST` | `/api/orders/pos` | Tạo đơn hàng bán lẻ tại quầy, ghi nhận sổ cái kho |
| **Flash Sale** | `POST` | `/api/webhook/simulate` | Mô phỏng nhận đơn TMĐT với kiểm soát khóa tương tranh |
| **Sổ cái kho** | `GET` | `/api/inventory/ledger` | Lấy dữ liệu sổ cái phân vùng theo tháng |
| **Hệ thống** | `GET` | `/api/health` | Kiểm tra tình trạng kết nối tới SQL Server 2022 |

---

## 🛠️ 10. Khắc Phục Sự Cố Thường Gặp

* **Lỗi 1: Port 1433 hoặc 5000 đã bị chiếm dụng**
  * *Xử lý:* Đổi port trong `docker-compose.yml` hoặc tắt ứng dụng đang chiếm port bằng lệnh:
    ```powershell
    Get-Process -Id (Get-NetTCPConnection -LocalPort 1433).OwningProcess | Stop-Process
    ```
* **Lỗi 2: Docker báo lỗi "Cannot connect to Docker daemon"**
  * *Xử lý:* Mở Docker Desktop từ màn hình Desktop và chờ icon chuyển sang màu xanh lá cây ("Engine running").
* **Lỗi 3: Kết nối SSMS báo lỗi SSL / Certificate**
  * *Xử lý:* Trong cửa sổ kết nối SSMS, chọn **Options** $\rightarrow$ Tích chọn **Trust Server Certificate**.

---

## 👥 11. Thông Tin Nhóm Thực Hiện

* **Giảng viên hướng dẫn:** Bộ môn Hệ Quản Trị Cơ Sở Dữ Liệu
* **Nhóm sinh viên thực hiện:**
  - Thành viên phụ trách CSDL: T-SQL Scripts, RLS, Indexes, Triggers, GIS.
  - Thành viên phụ trách Backend & DevOps: ASP.NET Core, Docker, GitHub Actions CI/CD.
  - Thành viên phụ trách Frontend: UI/UX POS, Dashboard & Webhook Simulator.

---
<div align="center">
  <sub>Đồ án Môn học Hệ Quản Trị Cơ Sở Dữ Liệu • Bản quyền thuộc về Nhóm tác giả © 2026</sub>
</div>
