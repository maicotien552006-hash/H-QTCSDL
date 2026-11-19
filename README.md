# OISM - Omnichannel Inventory and Sales Management System
> **Dự án Môn học: Hệ Quản Trị Cơ Sở Dữ Liệu (H-QTCSDL)**  
> **Repository:** [https://github.com/maicotien552006-hash/H-QTCSDL](https://github.com/maicotien552006-hash/H-QTCSDL)  
> **Công nghệ lõi:** Microsoft SQL Server 2022 (Compatibility Level 160) + ASP.NET Core 8.0 Web API + Modern Responsive Web POS (Tailwind CSS, Nginx) + Docker Compose + GitHub Actions CI/CD.

---

## 🏗️ Kiến Trúc Tổng Thể Hệ Thống

```text
               ┌────────────────────────────────────────────────────────┐
               │         Frontend Web App (PWA POS & Dashboard)         │
               │        - Giao diện bán hàng POS Fast Checkout          │
               │        - Quản lý đa kênh: Shopee, TikTok Shop, Lazada  │
               │        - Bảng đồ định vị chi nhánh & GPS (GIS)         │
               └──────────────────────────┬─────────────────────────────┘
                                          │ (HTTP REST API: /api/...)
                                          ▼
               ┌────────────────────────────────────────────────────────┐
               │          Backend Web API (ASP.NET Core 8.0)            │
               │        - Xác thực JWT Multi-Tenant                     │
               │        - Session Context kích hoạt RLS: @TenantId      │
               │        - Background Worker tự động hủy đơn giữ quá hạn │
               └──────────────────────────┬─────────────────────────────┘
                                          │ (T-SQL Stored Procedures & Triggers)
                                          ▼
               ┌────────────────────────────────────────────────────────┐
               │        Microsoft SQL Server 2022 Database Engine       │
               │  1. RCSI: Chống Deadlock đọc-ghi đồng thời             │
               │  2. RLS (Row-Level Security): Bảo mật cô lập Tenant    │
               │  3. Temporal Tables: Lưu lịch sử biến động giá niêm yết│
               │  4. Spatial GIS: Tính khoảng cách địa lý giao hàng     │
               │  5. Columnstore Index: Tăng tốc báo cáo phân tích      │
               │  6. Partitioning: Phân vùng Sổ cái kho theo tháng      │
               │  7. Append-Only Trigger: Chặn sửa/xóa Sổ cái           │
               │  8. WAC Trigger: Tự động tính giá vốn bình quân        │
               └────────────────────────────────────────────────────────┘
```

---

## 🚀 3 CÁCH KHỞI CHẠY ỨNG DỤNG

### Cách 1: Khởi Chạy Bằng Docker & Docker Compose (Khuyên dùng - 1 Bước)
Không cần cài đặt trước .NET SDK hay SQL Server vào máy tính:
1. Đảm bảo máy tính đã cài đặt và đang mở **Docker Desktop**.
2. Nhấp đúp vào tệp **`docker-start.bat`** (hoặc mở Terminal tại thư mục gốc và chạy):
   ```bash
   docker compose up -d --build
   ```
3. Chờ khoảng 15-20 giây để SQL Server 2022 khởi động và chạy seeder nạp tự động toàn bộ CSDL.
4. Truy cập các dịch vụ:
   * **Giao diện Web App:** [http://localhost:8080](http://localhost:8080)
   * **Backend API Health Check:** [http://localhost:5000/api/health](http://localhost:5000/api/health)
   * **SQL Server 2022:** `localhost,1433` *(User: `sa` | Mật khẩu: `Oism2026@StrongPassword!`)*

---

### Cách 2: Khởi Chạy Bằng SSMS & Backend .NET Cục Bộ
Dành cho việc mở trực tiếp **SQL Server Management Studio (SSMS 2022)** để debug truy vấn:
1. Mở SSMS 2022, mở tệp `SQLQuery1.sql` và nhấn **F5** để tạo Database `OISM` và dữ liệu mẫu.
2. Mở file `OISM_User_Accounts.sql` và `OISM_Spatial_GPS_Demo.sql` nhấn **F5** để cập nhật tài khoản và dữ liệu GPS.
3. Nhấp đúp vào tệp **`start.bat`**, chọn **[1]** để khởi động Backend và tự động mở Web App.
4. Mọi thao tác thanh toán, nhập hàng trên Web sẽ ghi thẳng vào SSMS theo thời gian thực!

---

### Cách 3: Chạy Độc Lập Giả Lập In-Memory (Trực tiếp trên Trình duyệt)
Nếu máy tính không có Docker hoặc SQL Server:
* Nhấp đúp mở trực tiếp tệp **`index.html`** trên bất kỳ trình duyệt nào (Chrome, Edge, Firefox).
* Hệ thống tự động chuyển sang chế độ **In-Memory Engine** với đầy đủ dữ liệu mẫu để thử nghiệm.

---

## 🛡️ 8 TÍNH NĂNG ĐẶC TRƯNG SQL SERVER 2022 ĐÃ TRIỂN KHAI

| STT | Tính Năng SQL Server 2022 | Đối Tượng Triển Khai | Mục Đích Nghiệp Vụ Trong OISM |
| :---: | :--- | :--- | :--- |
| **1** | **RCSI (Read Committed Snapshot Isolation)** | `ALTER DATABASE OISM SET READ_COMMITTED_SNAPSHOT ON` | Thu ngân đọc tồn kho không bao giờ chặn (block) thủ kho đang nhập hàng. Chống deadlock cao điểm. |
| **2** | **Row-Level Security (RLS)** | `sec.fn_TenantSecurityPredicate`, `sec.TenantIsolationPolicy` | Cô lập dữ liệu giữa các cửa hàng (Multi-Tenancy) ở tầng Database, ngăn chặn rò rỉ dữ liệu triệt để. |
| **3** | **Temporal Tables (System-Versioned)** | `dbo.ListedPrices`, `dbo.ListedPricesHistory` | Tự động lưu vết lịch sử biến động giá niêm yết theo thời gian chuẩn ISO mà không cần viết trigger. |
| **4** | **Spatial GIS (Hệ Tọa Độ WGS84 - SRID 4326)** | `dbo.Branches.Location` (`geography`), `Location.STDistance()` | Tính khoảng cách thực tế giữa khách hàng và các chi nhánh để đề xuất chi nhánh giao hàng gần nhất. |
| **5** | **Nonclustered Columnstore Index (NCCI)** | `NCCI_OrderItems_Analytics` trên `dbo.OrderItems` | Nén cột dữ liệu phân tích, tăng tốc truy vấn báo cáo doanh thu/lợi nhuận đa kênh nhanh gấp 10-100 lần. |
| **6** | **Table Partitioning (Phân Vùng Bảng)** | `pf_Ledger_Monthly`, `ps_Ledger_Monthly` trên `dbo.InventoryLedger` | Phân vùng sổ cái bất biến theo từng tháng, tối ưu hóa truy vấn kiểm kê và bảo trì dữ liệu lớn. |
| **7** | **Append-Only Ledger Protection Trigger** | `trg_InventoryLedger_AppendOnly` trên `dbo.InventoryLedger` | Chặn tuyệt đối mọi lệnh `UPDATE` và `DELETE` trên sổ cái kho; chỉ cho phép ghi mới (`INSERT`). |
| **8** | **Weighted Average Cost (WAC) Trigger** | `trg_PurchaseReceiptItems_WeightedAvgCost` trên `dbo.PurchaseReceiptItems` | Tự động tính toán lại giá vốn bình quân gia quyền ngay khi thủ kho nhập lô hàng mới. |

---

## 🔄 QUY TRÌNH CI/CD (GITHUB ACTIONS)
Hệ thống được tích hợp quy trình kiểm thử và đóng gói tự động tại `.github/workflows/ci-cd.yml` kích hoạt mỗi khi có `push` hoặc `pull_request` vào nhánh `main`:
1. **Job 1 (SQL Server Validation):** Khởi tạo container SQL Server 2022 thực thụ trong GitHub runner, nạp toàn bộ script DDL, Stored Procedures, Triggers và chạy test suite tự động.
2. **Job 2 (Backend API Build):** Biên dịch mã nguồn C# ASP.NET Core 8.0, kiểm tra lỗi cú pháp và restore NuGet dependencies.
3. **Job 3 (Docker Integration Test):** Tự động build image Docker cho cả Frontend và Backend, chạy `docker compose up`, kiểm tra healthcheck HTTP endpoint rồi dọn dẹp môi trường.

---

## 🔑 TÀI KHOẢN ĐĂNG NHẬP MẪU

| Cửa Hàng / Tenant | Email Đăng Nhập | Mật Khẩu | Vai Trò (Role) | Quyền Hạn |
| :--- | :--- | :---: | :---: | :--- |
| **Cửa hàng Thời trang Minh Anh** (Tenant 1) | `owner@minhanh.vn` | `123456` | **Owner** | Toàn quyền quản trị cửa hàng |
| **Cửa hàng Thời trang Minh Anh** (Tenant 1) | `thungan@minhanh.vn` | `123456` | **Cashier** | Quầy POS thu ngân & đơn hàng |
| **Cửa hàng Nông sản Hữu cơ Xanh** (Tenant 2) | `owner@nongsanxanh.vn` | `123456` | **Owner** | Quản trị cửa hàng nông sản |
| **Cửa hàng Nông sản Hữu cơ Xanh** (Tenant 2) | `thukho@nongsanxanh.vn` | `123456` | **Warehouse** | Quản lý kho & nhập xuất hàng |

---

## 📦 ĐỒNG BỘ MÃ NGUỒN LÊN GITHUB
Để đẩy toàn bộ mã nguồn lên repository nhóm:
* **Cách nhanh nhất:** Nhấp đúp vào tệp **`push_to_github.bat`** tại thư mục gốc.
* **Hoặc bằng lệnh Terminal:**
  ```bash
  git init
  git remote add origin https://github.com/maicotien552006-hash/H-QTCSDL.git
  git branch -M main
  git add -A
  git commit -m "feat: complete OISM system with Docker Compose, GitHub Actions CI/CD and modern UI"
  git push -u origin main
  ```
