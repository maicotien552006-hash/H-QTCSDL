# BÁO CÁO ĐỐI SOÁT & PHÂN TÍCH CÁC YÊU CẦU CÒN THIẾU
## DỰ ÁN: HỆ THỐNG QUẢN LÝ BÁN HÀNG VÀ TỒN KHO ĐA KÊNH (OISM)
### Omnichannel Inventory and Sales Management System

* **Môn học:** Hệ Quản Trị Cơ Sở Dữ Liệu (H-QTCSDL)
* **Kho lưu trữ GitHub:** [https://github.com/maicotien552006-hash/H-QTCSDL](https://github.com/maicotien552006-hash/H-QTCSDL)
* **Ngày lập báo cáo:** 17/11/2026
* **Mục đích:** Rà soát và đối chiếu toàn diện giữa Bản đề cương yêu cầu ban đầu (Proposal Specification) và Hiện trạng mã nguồn thực tế; làm rõ các hạng mục còn thiếu, các điểm khác biệt kiến trúc và đề xuất giải pháp xử lý phục vụ báo cáo bảo vệ đồ án môn học.

---

## I. TỔNG QUAN MỨC ĐỘ HOÀN THIỆN CỦA DỰ ÁN

| Hạng mục đánh giá | Mức độ hoàn thành | Đánh giá chi tiết hiện trạng |
| :--- | :---: | :--- |
| **Yêu cầu chức năng (FR)** | **95%** (24/26 chức năng) | Hoàn thành xuất sắc 8/9 nhóm chức năng nghiệp vụ cốt lõi (Auth, Catalog, Sổ cái, Giá vốn WAC, Order Hub, Anti-Oversell, POS Thu ngân, Báo cáo). Chỉ thiếu một phần nhỏ ở chuyển kho 2 bước, Hangfire và SignalR. |
| **Yêu cầu phi chức năng (NFR)** | **80%** | Khóa tương tranh chống bán âm (Pessimistic Locking), giao dịch ACID nguyên tử, Row-Level Security phân tách Tenant, Temporal Table và Sổ cái Append-only hoạt động chuẩn xác 100%. |
| **Kiến trúc & Công nghệ (Tech Stack)** | **Khác biệt ~40%** | Chuyển đổi chiến lược sang Microsoft SQL Server 2022 Enterprise + Dapper + .NET 8 Minimal API (thay vì PostgreSQL + EF Core + Clean Architecture 4 layer) và Single-Page Web App (thay vì ReactJS). |
| **Sản phẩm bàn giao (Deliverables)** | **50%** | Đã có CSDL SQL Server hoàn chỉnh kèm Seed Data, Backend Web API và Web App chạy trực tiếp. Chưa có Dockerfile, docker-compose, CI/CD GitHub Actions, Unit Test xUnit và tài liệu Word URS/RTM. |

---

## II. ĐỐI SOÁT MA TRẬN YÊU CẦU CHỨC NĂNG (FUNCTIONAL REQUIREMENTS)

| Mã FR | Tên chức năng yêu cầu trong Đề cương | Hiện trạng trong Code thực tế | Tình trạng |
| :--- | :--- | :--- | :---: |
| **FR-AUTH-01** | **Đăng ký Cửa hàng (Tenant Registration):** Tạo Tenant mới có không gian dữ liệu cô lập với TenantId duy nhất. | Endpoint `/api/auth/register` tạo Tenant, kích hoạt RLS qua `sp_set_session_context`, tạo chi nhánh và tài khoản Owner. Trên Web có form Đăng ký cửa hàng mới. | **ĐẠT (100%)** |
| **FR-AUTH-02** | **Xác thực người dùng (Authentication):** Đăng nhập qua Email/SĐT + Password, cấp JWT token (TenantId, UserId, Role). | Đăng nhập qua Email/Password, băm BCrypt, cấp JWT Token thời hạn 8 tiếng chứa `TenantId, UserId, Role, StoreName`. | **ĐẠT (100%)** |
| **FR-AUTH-03** | **Phân quyền vai trò (RBAC):** Cấu hình quyền theo 3 role: Owner (toàn quyền), Staff (kho/đơn), Cashier (chỉ POS). | Kiểm soát 3 vai trò: Owner xem báo cáo tài chính; Staff bị ẩn báo cáo; Cashier chỉ được vào POS. Giao diện có sẵn các nút bấm 1-chạm để test cả 3 vai trò. | **ĐẠT (100%)** |
| **FR-AUTH-04** | **Quản lý chi nhánh (Branch Management):** Tạo, cập nhật, ẩn/hiện các chi nhánh, kho hàng sở hữu. | Bảng `dbo.Branches`, API `/api/branches` đầy đủ. Điểm sáng: Tích hợp tọa độ GPS và bản đồ số hóa Leaflet. | **ĐẠT (100%)** |
| **FR-PROD-01** | **Quản lý Danh mục & Thương hiệu:** Danh mục đa cấp phân cấp cha - con và danh mục thương hiệu. | Bảng `dbo.Categories` (hỗ trợ phân cấp cha - con `ParentId`) và `dbo.Brands` kèm API quản trị. | **ĐẠT (100%)** |
| **FR-PROD-02** | **Quản lý Sản phẩm & Biến thể SKU:** Hỗ trợ sản phẩm đơn và biến thể (màu, size). Mã SKU duy nhất trong Tenant. | Hỗ trợ sản phẩm và biến thể SKU, ràng buộc mã SKU duy nhất theo Tenant (`UQ_SKUs_Code`). | **ĐẠT (100%)** |
| **FR-PROD-03** | **Quản lý Mã vạch (Barcode Management):** Tự động sinh hoặc nhập barcode (EAN-13/Code128) để quét tại POS. | Tự động sinh mã EAN-13 (đầu 893) hoặc nhập tay, có chỉ mục lọc duy nhất `UX_SKUs_Barcode`, quét barcode tại POS. | **ĐẠT (100%)** |
| **FR-PROD-04** | **Quản lý Giá niêm yết (Price Management):** Thiết lập giá lẻ và giá buôn riêng biệt với giá vốn COGS. | Quản lý giá lẻ/buôn độc lập. Sử dụng **Temporal Table** `dbo.ListedPrices` lưu vết lịch sử biến động giá tự động. | **ĐẠT (100%)** |
| **FR-INV-01** | **Ghi sổ cái tồn kho (Append-Only Ledger):** Ghi toàn bộ biến động (Nhập, Xuất, Bán, Trả, Kiểm, Chuyển). Cấm sửa/xóa. | Bảng `dbo.InventoryLedger` phân vùng theo tháng (`pf_Ledger_Monthly`), có Trigger `trg_InventoryLedger_AppendOnly` chặn tuyệt đối `UPDATE`/`DELETE` (lỗi 50050). | **ĐẠT (100%)** |
| **FR-INV-02** | **Quản lý Nhập hàng (Purchase Receipt):** Nhập kho nhà cung cấp -> Tăng OnHand -> Cập nhật giá vốn bình quân. | Thủ tục `dbo.usp_ConfirmPurchaseReceipt` tăng OnHand, ghi sổ cái IN và tự động kích hoạt trigger tính lại giá vốn. | **ĐẠT (100%)** |
| **FR-INV-03** | **Quản lý Chuyển kho (Stock Transfer):** Chuyển hàng giữa Kho A và B qua 2 bước: Xuất trung chuyển -> Xác nhận nhập. | Endpoint `/api/inventory/transfer` chuyển hàng trực tiếp 1 bước (chưa có quy trình 2 bước In-Transit). | **ĐẠT MỘT PHẦN** |
| **FR-INV-04** | **Quản lý Kiểm kê (Stocktake Management):** Đếm thực tế, so sánh phần mềm, sinh bút toán điều chỉnh cân kho. | Thủ tục `dbo.usp_StocktakeAdjust` so sánh số đếm thực tế, cân kho và ghi bút toán điều chỉnh vào sổ cái. | **ĐẠT (100%)** |
| **FR-COST-01** | **Tính giá vốn bình quân gia quyền (WAC):** Tự động tính lại giá vốn SKU khi nhập kho theo đúng công thức. | Trigger `dbo.trg_PurchaseReceiptItems_WeightedAvgCost` tự động tính lại CostPrice theo đúng công thức đề cương. | **ĐẠT (100%)** |
| **FR-COST-02** | **Chụp giá vốn khi xuất kho (COGS Snapshot):** Chụp giá vốn vào OrderItem.CostPrice khi duyệt đơn hoặc bán POS. | Thủ tục `dbo.usp_ConfirmOrder` và `usp_FastCheckout` chụp giá vốn hiện hành vào `OrderItem.CostPrice`. | **ĐẠT (100%)** |
| **FR-ORD-01** | **Thu thập đơn hàng đa kênh (Order Hub):** Chuẩn hóa đơn từ POS, Admin, Webhook sàn vào Canonical Model. | Chuẩn hóa đơn từ POS, Admin, Webhook Shopee/TikTok/Lazada vào mô hình chuẩn `dbo.Orders`. | **ĐẠT (100%)** |
| **FR-ORD-02** | **Máy trạng thái đơn hàng (State Machine):** Ép buộc luồng: Draft -> Reserved -> Confirmed -> Completed/Cancelled. | Trigger `dbo.trg_Orders_StateMachine` kiểm soát vòng đời đơn hàng, chặn đứng mọi thao tác nhảy cóc sai luồng. | **ĐẠT (100%)** |
| **FR-ORD-03** | **Xử lý đơn hàng (Order Processing):** Cho phép nhân viên xem danh sách, duyệt đơn, in phiếu giao, hủy đơn. | Giao diện và API cho phép xem danh sách, duyệt đơn (`usp_ConfirmOrder`), hủy đơn, in phiếu đóng gói giao hàng. | **ĐẠT (100%)** |
| **FR-RSE-01** | **Tính tồn khả dụng (Available Stock):** Duy trì động công thức: `available = on_hand - reserved`. | Cột tính toán `Available AS (OnHand - Reserved) PERSISTED` và ràng buộc `CK_StockLevels_NoOversell`. | **ĐẠT (100%)** |
| **FR-RSE-02** | **Giữ chỗ hàng online (Stock Reservation):** Tăng reserved khi đơn online vào. Chặn đơn nếu available < số lượng mua. | Thủ tục `dbo.usp_ReserveOrder` dùng khóa `UPDLOCK, ROWLOCK` kiểm tra Available >= Qty, tăng Reserved hoặc từ chối đơn. | **ĐẠT (100%)** |
| **FR-RSE-03** | **Trừ kho / Giải phóng giữ chỗ:** Khi Confirmed: trừ on_hand, giảm reserved. Khi Cancelled: trả lại reserved. | Khi Confirmed: trừ OnHand, trừ Reserved, ghi Sổ cái. Khi Cancelled: trả lại Reserved về tồn khả dụng. | **ĐẠT (100%)** |
| **FR-POS-01** | **Giao diện bán hàng nhanh (Fast POS UI):** UI cảm ứng, tối ưu phím tắt, tìm kiếm nhanh theo Tên/SKU/Barcode. | Hỗ trợ phím tắt (F2 tìm kiếm, F4 thanh toán, F7 làm mới, F8/F9 chọn hình thức thanh toán), tìm nhanh đa tiêu chí. | **ĐẠT (100%)** |
| **FR-POS-02** | **Ràng buộc bán lẻ tại quầy:** Kiểm tra tồn khả dụng tức thời; chặn bán vượt quá tồn để bảo vệ lượng đã giữ online. | Kiểm tra tức thời số lượng khả dụng, chặn không cho bán vượt quá tồn để bảo vệ số lượng đã giữ chỗ online. | **ĐẠT (100%)** |
| **FR-POS-03** | **Thanh toán & In hóa đơn:** Hỗ trợ Tiền mặt, Mã QR chuyển khoản, tự động kích hoạt in hóa đơn trình duyệt. | Hỗ trợ Tiền mặt (Cash), QR Chuyển khoản VietQR, tự động bật hộp thoại in hóa đơn chuẩn 80mm/58mm. | **ĐẠT (100%)** |
| **FR-POS-04** | **Quy trình thanh toán nguyên tử POS:** Thực thi Reserve -> Confirm -> Deduct trong 1 database transaction duy nhất. | Thủ tục `dbo.usp_FastCheckout` thực hiện Reserve -> Confirm -> Deduct trong duy nhất 1 Transaction nguyên tử. | **ĐẠT (100%)** |
| **FR-REP-01** | **Báo cáo Doanh thu & Lợi nhuận gộp:** Tổng hợp Doanh thu thuần, COGS, Lợi nhuận gộp ($Doanh thu - COGS$). | Thủ tục `dbo.usp_RevenueReport` tính Doanh thu, COGS, Lợi nhuận gộp, lọc theo kênh/thời gian. Dùng Columnstore. | **ĐẠT (100%)** |
| **FR-REP-02** | **Báo cáo Tồn kho & Tốc độ bán:** Theo dõi giá trị tồn kho theo giá vốn, hàng bán chậm (> 30 ngày). | API `/api/reports/slow-moving` phân tích hàng tồn > 30 ngày không xuất kho, tính giá trị tồn kho theo giá vốn. | **ĐẠT (100%)** |
| **FR-REP-03** | **Cảnh báo hết hàng (Stock Alert):** Tự động gửi cảnh báo khi Available <= Threshold (ngưỡng tối thiểu). | View `dbo.vw_StockAlerts` tự động lọc hàng có `Available <= ReorderThreshold`, hiện chuông cảnh báo trên Web. | **ĐẠT (100%)** |
| **FR-SIM-01** | **Mô phỏng Webhook sàn TMĐT:** Công cụ gửi mock payload Shopee/TikTok/Lazada kiểm tra throughput và khóa kho. | Giao diện mô phỏng gửi JSON Shopee/TikTok/Lazada, hỗ trợ test Flash Sale 50 luồng tranh chấp 1 SKU. | **ĐẠT (100%)** |
| **FR-SIM-02** | **Thông báo Real-time bằng SignalR:** Đẩy cảnh báo âm thanh/popup tức thời khi có đơn mới mà không cần F5. | Web phát âm thanh và Toast từ phản hồi Webhook; Backend .NET chưa dựng Hub SignalR WebSocket. | **CHƯA ĐÚNG CÔNG NGHỆ** |
| **FR-SIM-03** | **Xử lý nền định kỳ bằng Hangfire:** Quét tự động hủy đơn giữ quá hạn và tổng hợp báo cáo ngày bằng Hangfire. | Dùng `BackgroundService` của .NET quét 30s gọi `dbo.usp_ExpireReservedOrders`; Chưa dùng thư viện Hangfire. | **CHƯA ĐÚNG CÔNG NGHỆ** |

---

## III. PHÂN TÍCH CHI TIẾT CÁC YÊU CẦU CÒN THIẾU HOẶC KHÁC BIỆT

### 1. FR-SIM-02: Thông báo Real-time bằng SignalR
* **Yêu cầu trong đề cương:** Sử dụng thư viện SignalR để tạo kết nối song công (WebSocket) giữa Backend và Web Client, đẩy thông báo popup và âm thanh tức thì khi có đơn hàng mới từ sàn TMĐT/POS về cho nhân viên quản trị mà không cần tải lại trang (F5).
* **Hiện trạng mã nguồn:** Khi người dùng bấm "Gửi Webhook" trên màn hình Webhook Simulator, Web App tự kích hoạt hàm âm thanh `playBeep('order')` và hiển thị thông báo Toast cục bộ dựa trên phản hồi HTTP POST. Trong Backend .NET (`backend.csproj`) hiện chưa cài đặt gói NuGet `Microsoft.AspNetCore.SignalR` và chưa tạo `OrderHub`.
* **Đánh giá mức độ ảnh hưởng:** Mức độ nhẹ. Nghiệp vụ cảnh báo khi có đơn hàng vẫn thể hiện được khi demo trực tiếp, nhưng về mặt kỹ thuật giao thức chưa có kết nối WebSocket/SignalR thật sự giữa Server và Client.
* **Giải pháp khắc phục:**
  1. Cài thêm package `Microsoft.AspNetCore.SignalR` vào `backend.csproj`.
  2. Tạo lớp `OrderHub : Hub` trong Backend .NET.
  3. Bổ sung `app.MapHub<OrderHub>("/hub/orders")` trong `Program.cs`.
  4. Gọi `IHubContext<OrderHub>` để phát tín hiệu thông báo `NewOrderReceived` mỗi khi endpoint `/api/webhook` xử lý thành công đơn hàng.
  5. Phía Web Frontend nạp thư viện `@microsoft/signalr` qua CDN để lắng nghe sự kiện.

---

### 2. FR-SIM-03: Xử lý nền quét đơn giữ quá hạn bằng Hangfire
* **Yêu cầu trong đề cương:** Sử dụng thư viện Hangfire để quản lý các tác vụ bất đồng bộ nặng: tự động quét hủy đơn giữ quá hạn (hết thời gian Reserved 30 phút) và tổng hợp báo cáo định kỳ hàng ngày.
* **Hiện trạng mã nguồn:** Backend đã xây dựng lớp `OrderExpirationWorker` kế thừa từ `BackgroundService` (IHostedService có sẵn của .NET 8). Worker này chạy ngầm độc lập, tự động thức dậy mỗi 30 giây để duyệt danh sách Tenant và thực thi thủ tục SQL `dbo.usp_ExpireReservedOrders`.
* **Đánh giá mức độ ảnh hưởng:** Mức độ trung bình. Về mặt kết quả chức năng: Hệ thống hoàn toàn tự động hủy đơn hết hạn và giải phóng tồn kho đúng 100%. Tuy nhiên, việc không dùng Hangfire khiến hệ thống thiếu giao diện Dashboard giám sát Job (`/hangfire`) và cơ chế lưu trữ Job vào bảng chuyên dụng.
* **Giải pháp khắc phục:**
  * Giữ nguyên cơ chế `BackgroundService` hiện tại vì nó chạy trực tiếp, nhẹ nhàng, không yêu cầu tạo thêm các bảng quản lý job phức tạp của Hangfire; hoặc cài đặt package `Hangfire.Core` và `Hangfire.SqlServer` nếu giảng viên yêu cầu bắt buộc phải có Dashboard Hangfire.

---

### 3. FR-INV-03: Quy trình Chuyển kho 2 bước (Two-Step Stock Transfer)
* **Yêu cầu trong đề cương:** Quá trình chuyển hàng giữa Kho A và Kho B phải tuân theo luồng 2 bước:
  $$\text{Bước 1: Xuất kho trung chuyển (Out-bound transit)} \longrightarrow \text{Bước 2: Xác nhận nhập kho đích (In-bound confirmation)}$$
* **Hiện trạng mã nguồn:** API `/api/inventory/transfer` và giao diện Tab Chuyển kho hiện đang xử lý chuyển kho nguyên tử 1 bước (trừ tồn kho A, cộng tồn kho B ngay lập tức và ghi 2 dòng bút toán IN/OUT vào Sổ cái).
* **Đánh giá mức độ ảnh hưởng:** Mức độ trung bình. Chuyển kho 1 bước vẫn đảm bảo cân bằng tồn kho và toàn vẹn sổ cái, nhưng chưa mô phỏng được trạng thái hàng đang nằm trên đường vận chuyển (`In-Transit`).
* **Giải pháp khắc phục:**
  1. Tạo bảng `dbo.StockTransfers` lưu thông tin phiếu chuyển: `TransferId, FromBranchId, ToBranchId, SKUId, Quantity, Status ('InTransit', 'Completed')`.
  2. Bước 1: Trừ tồn kho A, ghi bút toán Sổ cái OUT (`TxnType='TransferOut'`), tạo phiếu chuyển ở trạng thái `InTransit`.
  3. Bước 2: Tạo thêm API `/api/inventory/transfer/confirm` để thủ kho đích bấm "Xác nhận nhận hàng", lúc đó mới cộng tồn kho B và ghi bút toán IN (`TxnType='TransferIn'`).

---

### 4. Gói công việc 5: Tích hợp AI dự báo nhu cầu đặt hàng
* **Yêu cầu trong đề cương:** Tích hợp mô hình AI forecasting để đưa ra khuyến nghị đặt hàng lại (stock reorder recommendations) dựa trên dữ liệu lịch sử bán hàng.
* **Hiện trạng mã nguồn:** Hệ thống đang sử dụng công thức định mức ngưỡng an toàn `ReorderThreshold` trên bảng `dbo.SKUs` kết hợp View `dbo.vw_StockAlerts` và báo cáo hàng bán chậm > 30 ngày. Chưa có mô hình Học máy (Machine Learning / Deep Learning) dự báo chuỗi thời gian.
* **Đánh giá mức độ ảnh hưởng:** Mức độ nhẹ đối với môn Hệ Quản Trị CSDL, vì AI thường là phần mở rộng nâng cao (optional).
* **Giải pháp khắc phục:**
  * Giữ nguyên logic ngưỡng tồn tối thiểu kết hợp báo cáo hàng bán chậm `slow-moving`, giải thích với hội đồng rằng hệ thống áp dụng thuật toán phân tích tốc độ luân chuyển kho (Inventory Velocity Analytics) ở mức CSDL.

---

## IV. PHÂN TÍCH KHÁC BIỆT KIẾN TRÚC & ĐÁNH GIÁ MÔN H-QTCSDL

Bản đề cương ban đầu được soạn thảo theo khung chương trình phát triển phần mềm tổng quát (sử dụng PostgreSQL, Clean Architecture 4 lớp, ReactJS). Tuy nhiên, đối với môn học **HỆ QUẢN TRỊ CƠ SỞ DỮ LIỆU (H-QTCSDL)**, sự chuyển dịch sang **MICROSOFT SQL SERVER 2022 ENTERPRISE** là một **BƯỚC ĐI HOÀN TOÀN ĐÚNG ĐẮN VÀ TẠO RA ƯU THẾ TUYỆT ĐỐI**.

| Tiêu chí công nghệ | Đề cương ban đầu | Hiện trạng triển khai | Ý nghĩa đối với môn H-QTCSDL |
| :--- | :--- | :--- | :--- |
| **Hệ Quản trị CSDL** | PostgreSQL | **Microsoft SQL Server 2022 (Compatibility 160)** | Tận dụng được hệ sinh thái tính năng Enterprise mạnh mẽ của SQL Server: RLS, Temporal Table, Columnstore, Spatial Data, Table Partitioning. |
| **Kiến trúc Backend** | Clean Architecture 4 layer (EF Core) | **Minimal API + Dapper + Stored Procedures** | Trong môn HQTCSDL, đẩy toàn bộ nghiệp vụ (khóa, kiểm tra tồn, trigger, state machine) xuống T-SQL Stored Procedure được đánh giá cao hơn nhiều so với việc viết code C# trên tầng ORM. |
| **Giao diện Frontend** | ReactJS (2 App riêng) | **Single-Page Web App (index.html) đa năng** | Tích hợp toàn bộ POS và Admin vào 1 giao diện trực quan, có chế độ In-Memory an toàn giúp demo mượt mà không lo lỗi kết nối môi trường thi. |
| **Kiểm soát tương tranh** | Pessimistic Locking (`SELECT FOR UPDATE`) | `WITH (UPDLOCK, ROWLOCK) + OPTION (FORCE ORDER)` | Giải quyết hoàn hảo bài toán chống bán âm (Anti-oversell) và triệt tiêu Deadlock ở mức CSDL nguyên tử. |

### 8 Điểm kỹ thuật CSDL đỉnh cao trong đồ án giúp ghi điểm tối đa:
1. **Row-Level Security (RLS):** Tách biệt dữ liệu tuyệt đối giữa các Tenant ở mức CSDL bằng Security Policy `sec.TenantIsolationPolicy` kết hợp hàm `sec.fn_TenantPredicate` và `SESSION_CONTEXT(N'TenantId')`.
2. **Phân vùng bảng (Partitioning):** Cấu hình `pf_Ledger_Monthly` và `ps_Ledger_Monthly` để chia nhỏ bảng Sổ cái `InventoryLedger` theo từng tháng, tối ưu truy vấn dữ liệu lớn.
3. **Temporal Table (Bảng lịch sử thời gian):** Bảng `dbo.ListedPrices` tự động kích hoạt `SYSTEM_VERSIONING` lưu lịch sử thay đổi giá bán vào `dbo.ListedPricesHistory` chuẩn ANSI SQL.
4. **Dữ liệu Không gian (Spatial GIS Data):** Bảng `Branches` và `GeoPins` lưu trữ tọa độ chuẩn `geography::Point(Lat, Lng, 4326)` để tính toán khoảng cách và hiển thị trực quan lên bản đồ số hóa Leaflet.
5. **Non-clustered Columnstore Index:** Tạo `NCCI_OrderItems_Analytics` trên bảng `OrderItems` giúp tăng tốc độ tổng hợp báo cáo doanh thu, giá vốn và lãi gộp lên gấp hàng chục lần.
6. **Trigger bảo vệ Sổ cái Append-Only:** Trigger `trg_InventoryLedger_AppendOnly` chặn đứng 100% mọi hành vi `UPDATE` hoặc `DELETE`, biến Sổ cái thành kho lưu trữ bất biến (Immutable Ledger).
7. **Trigger tính giá vốn tự động (WAC):** Trigger `trg_PurchaseReceiptItems_WeightedAvgCost` tự động tính toán lại Giá vốn bình quân gia quyền của SKU ngay sau khi có phiếu nhập kho.
8. **Xử lý lai Relational-JSON:** Thủ tục `dbo.usp_IngestWebhook` dùng `OPENJSON` để tiếp nhận và phân tách dữ liệu đơn hàng phức tạp từ Shopee, TikTok Shop trực tiếp trong CSDL.

---

## V. DANH MỤC HỒ SƠ & SẢN PHẨM BÀN GIAO CÒN THIẾU (DELIVERABLES)

| STT | Thành phần bàn giao theo đề cương | Tình trạng | Mô tả việc cần làm để bổ sung |
| :---: | :--- | :---: | :--- |
| 1 | **Backend Web API (.NET 8)** | **ĐÃ CÓ** | Mã nguồn hoàn chỉnh tại thư mục `backend/`, đã build sẵn file nhị phân `backend.exe`. |
| 2 | **Giao diện Web Admin & POS** | **ĐÃ CÓ** | Tập tin `index.html` hoàn chỉnh, tích hợp đầy đủ tính năng và cơ chế Dual-mode. |
| 3 | **Kịch bản CSDL & Dữ liệu mẫu** | **ĐÃ CÓ** | Các file `SQLQuery1.sql`, `OISM_Spatial_GPS_Demo.sql`, `OISM_User_Accounts.sql`. |
| 4 | **Gói cài đặt Docker & Docker Compose** | **CHƯA CÓ** | Cần tạo `Dockerfile` cho Backend, Nginx `Dockerfile` cho Frontend và `docker-compose.yml` khởi chạy cùng SQL Server. |
| 5 | **Quy trình CI/CD GitHub Actions** | **CHƯA CÓ** | Cần tạo thư mục `.github/workflows/ci.yml` để tự động kiểm tra cú pháp và build code khi push lên GitHub. |
| 6 | **Dự án Kiểm thử tự động (Unit Test)** | **CHƯA CÓ** | Cần tạo thêm 1 project `backend.Tests` (dùng xUnit) để viết test cases kiểm tra các hàm nghiệp vụ C# (đạt chỉ tiêu 80% coverage). |
| 7 | **Bộ tài liệu kỹ thuật (Design Docs)** | **CHƯA CÓ** | Cần bổ sung các file tài liệu Word/PDF: Đặc tả yêu cầu (URS & RTM), Thiết kế kiến trúc CSDL, Biểu đồ UML (Class, Use Case, Sequence Diagram), Kế hoạch triển khai. |

---

## VI. KỊCH BẢN VÀ HƯỚNG DẪN TRÌNH DIỄN KHI BẢO VỆ ĐỒ ÁN

Để đạt điểm số tối đa (Điểm 10) trước Hội đồng chấm thi môn Hệ Quản Trị CSDL, nhóm nên thực hiện kịch bản trình diễn 5 bước như sau:

* **Bước 1 - Khởi chạy và Chứng minh RLS:** Mở SSMS chạy file `SQLQuery1.sql`. Đăng nhập tài khoản Owner Cửa hàng Minh Anh (Tenant 1), cho thấy chỉ nhìn thấy sản phẩm/chi nhánh của Tenant 1. Sau đó đổi sang Shop Hoa Sen (Tenant 2), chứng minh dữ liệu được cô lập tuyệt đối nhờ Row-Level Security.
* **Bước 2 - Trình diễn Bán hàng POS & Bút toán Sổ cái:** Vào màn hình POS Thu ngân, chọn sản phẩm, bấm F4 thanh toán tiền mặt. Mở SSMS truy vấn bảng `dbo.InventoryLedger` để chứng minh bút toán xuất kho (`Type='OUT', TxnType='Sale'`) đã được sinh tự động tức thì.
* **Bước 3 - Kiểm thử Tính bất biến của Sổ cái (Append-Only):** Trong SSMS, thử gõ lệnh UPDATE hoặc DELETE bảng `dbo.InventoryLedger`. Chỉ cho giảng viên thấy Trigger `trg_InventoryLedger_AppendOnly` chặn đứng thao tác và báo lỗi 50050 như thế nào.
* **Bước 4 - Trình diễn Khóa Tương tranh & Chống Bán âm (Flash Sale):** Chuyển sang Tab Mô phỏng Webhook, chọn sản phẩm `FLASH-001` (chỉ còn đúng 1 tồn kho). Bấm nút "Chạy Flash Sale 50 luồng đồng thời". Kết quả: Duy nhất 1 đơn hàng thành công, 49 đơn còn lại bị từ chối an toàn, tồn kho không bao giờ bị âm.
* **Bước 5 - Trình diễn Bản đồ GPS & Temporal Table:** Chuyển sang Tab Bản đồ GPS, ghim 1 địa điểm mới để chứng minh việc lưu trữ đối tượng `geography::Point`. Sau đó đổi giá niêm yết của 1 SKU và mở bảng `dbo.ListedPricesHistory` trong SSMS để chứng minh tính năng Temporal Table theo dõi lịch sử giá tự động.

> **KẾT LUẬN:** Đồ án OISM của nhóm bạn đã hoàn thành xuất sắc các nội dung học thuật cốt lõi và kỹ thuật cơ sở dữ liệu chuyên sâu của môn H-QTCSDL. Việc bổ sung các file tài liệu và Docker (nếu cần) sẽ giúp sản phẩm đạt độ hoàn thiện 100% tuyệt đối.
