/* =============================================================================
   OISM - Hệ thống quản lý bán hàng và tồn kho đa kênh
   Script SQL Server 2022 (compatibility level 160) - Phiên bản đã sửa lỗi 100%
============================================================================= */
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================ 0. DATABASE + RCSI ============================ */
USE master;
GO

-- Xóa database cũ nếu đã tồn tại để tránh lỗi trùng lặp (Idempotent)
IF DB_ID(N'OISM') IS NOT NULL 
BEGIN
    ALTER DATABASE OISM SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE OISM;
END;
GO

CREATE DATABASE OISM;
GO
ALTER DATABASE OISM SET COMPATIBILITY_LEVEL = 160;
ALTER DATABASE OISM SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO
USE OISM;
GO

/* ===================== 1. PARTITION FUNCTION / SCHEME ======================= */
DECLARE @d date = '2026-01-01', @list nvarchar(max) = N'';
WHILE @d <= '2027-12-01'
BEGIN
    SET @list += CASE WHEN @list = N'' THEN N'' ELSE N',' END + QUOTENAME(CONVERT(char(10), @d, 23), '''');
    SET @d = DATEADD(MONTH, 1, @d);
END;
EXEC (N'CREATE PARTITION FUNCTION pf_Ledger_Monthly (datetime2(3)) AS RANGE RIGHT FOR VALUES (' + @list + N');');
GO

CREATE PARTITION SCHEME ps_Ledger_Monthly AS PARTITION pf_Ledger_Monthly ALL TO ([PRIMARY]);
GO

/* ============================ 2. BẢNG ======================================= */
CREATE TABLE dbo.Tenants (
    TenantId  int IDENTITY(1,1) CONSTRAINT PK_Tenants PRIMARY KEY,
    Name      nvarchar(200) NOT NULL,
    IsActive  bit NOT NULL CONSTRAINT DF_Tenants_Active DEFAULT 1,
    CreatedAt datetime2(3) NOT NULL CONSTRAINT DF_Tenants_Created DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Users (
    UserId       int IDENTITY(1,1) CONSTRAINT PK_Users PRIMARY KEY,
    TenantId     int NOT NULL CONSTRAINT FK_Users_Tenants REFERENCES dbo.Tenants(TenantId),
    FullName     nvarchar(150) NOT NULL,
    Email        nvarchar(200) NULL,
    Phone        nvarchar(20)  NULL,
    PasswordHash nvarchar(200) NOT NULL,
    [Role]       nvarchar(10)  NOT NULL CONSTRAINT CK_Users_Role CHECK ([Role] IN (N'Owner', N'Staff', N'Cashier')),
    IsActive     bit NOT NULL CONSTRAINT DF_Users_Active DEFAULT 1,
    CONSTRAINT UQ_Users_Email UNIQUE (TenantId, Email)
);

CREATE TABLE dbo.Branches (
    BranchId  int IDENTITY(1,1) CONSTRAINT PK_Branches PRIMARY KEY,
    TenantId  int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    Name      nvarchar(150) NOT NULL,
    Address   nvarchar(300) NULL,
    IsVisible bit NOT NULL DEFAULT 1,
    CONSTRAINT FK_Branches_Tenants FOREIGN KEY (TenantId) REFERENCES dbo.Tenants(TenantId)
);

CREATE TABLE dbo.Categories (
    CategoryId int IDENTITY(1,1) CONSTRAINT PK_Categories PRIMARY KEY,
    TenantId   int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    ParentId   int NULL CONSTRAINT FK_Categories_Parent REFERENCES dbo.Categories(CategoryId),
    Name       nvarchar(150) NOT NULL
);

CREATE TABLE dbo.Brands (
    BrandId  int IDENTITY(1,1) CONSTRAINT PK_Brands PRIMARY KEY,
    TenantId int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    Name     nvarchar(150) NOT NULL
);

CREATE TABLE dbo.Products (
    ProductId  int IDENTITY(1,1) CONSTRAINT PK_Products PRIMARY KEY,
    TenantId   int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    CategoryId int NULL CONSTRAINT FK_Products_Categories REFERENCES dbo.Categories(CategoryId),
    BrandId    int NULL CONSTRAINT FK_Products_Brands REFERENCES dbo.Brands(BrandId),
    Name       nvarchar(250) NOT NULL,
    IsActive   bit NOT NULL DEFAULT 1
);

CREATE TABLE dbo.SKUs (
    SKUId            int IDENTITY(1,1) CONSTRAINT PK_SKUs PRIMARY KEY,
    TenantId         int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    ProductId        int NOT NULL CONSTRAINT FK_SKUs_Products REFERENCES dbo.Products(ProductId),
    SkuCode          nvarchar(50) NOT NULL,
    VariantName      nvarchar(100) NULL,
    Barcode          nvarchar(20) NULL,
    CostPrice        decimal(18,4) NOT NULL DEFAULT 0,
    ReorderThreshold int NOT NULL DEFAULT 5,
    IsActive         bit NOT NULL DEFAULT 1,
    CONSTRAINT UQ_SKUs_Code UNIQUE (TenantId, SkuCode)
);
CREATE UNIQUE INDEX UX_SKUs_Barcode ON dbo.SKUs (TenantId, Barcode) WHERE Barcode IS NOT NULL;

-- Temporal Table
CREATE TABLE dbo.ListedPrices (
    PriceId        int IDENTITY(1,1) CONSTRAINT PK_ListedPrices PRIMARY KEY CLUSTERED,
    TenantId       int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    SKUId          int NOT NULL CONSTRAINT FK_ListedPrices_SKUs REFERENCES dbo.SKUs(SKUId),
    RetailPrice    decimal(18,2) NOT NULL CONSTRAINT CK_ListedPrices_Retail CHECK (RetailPrice >= 0),
    WholesalePrice decimal(18,2) NOT NULL CONSTRAINT CK_ListedPrices_Wholesale CHECK (WholesalePrice >= 0),
    SysStart       datetime2(7) GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
    SysEnd         datetime2(7) GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
    PERIOD FOR SYSTEM_TIME (SysStart, SysEnd),
    CONSTRAINT UQ_ListedPrices_Sku UNIQUE (TenantId, SKUId)
) WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ListedPricesHistory));

CREATE TABLE dbo.StockLevels (
    TenantId  int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    BranchId  int NOT NULL CONSTRAINT FK_StockLevels_Branches REFERENCES dbo.Branches(BranchId),
    SKUId     int NOT NULL CONSTRAINT FK_StockLevels_SKUs REFERENCES dbo.SKUs(SKUId),
    OnHand    int NOT NULL DEFAULT 0,
    Reserved  int NOT NULL DEFAULT 0,
    Available AS (OnHand - Reserved) PERSISTED,
    UpdatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_StockLevels PRIMARY KEY CLUSTERED (BranchId, SKUId),
    CONSTRAINT CK_StockLevels_NoOversell CHECK (OnHand >= 0 AND Reserved >= 0 AND Reserved <= OnHand)
);
CREATE INDEX IX_StockLevels_Tenant_Sku ON dbo.StockLevels (TenantId, SKUId) INCLUDE (OnHand, Reserved);

-- Sổ cái append-only
CREATE TABLE dbo.InventoryLedger (
    LedgerId      bigint IDENTITY(1,1) NOT NULL,
    TenantId      int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    BranchId      int NOT NULL CONSTRAINT FK_Ledger_Branches REFERENCES dbo.Branches(BranchId),
    SKUId         int NOT NULL CONSTRAINT FK_Ledger_SKUs REFERENCES dbo.SKUs(SKUId),
    [Type]        varchar(3) NOT NULL CONSTRAINT CK_Ledger_Type CHECK ([Type] IN ('IN', 'OUT')),
    TxnType       nvarchar(20) NOT NULL
                  CONSTRAINT CK_Ledger_TxnType CHECK (TxnType IN (N'Import', N'Export', N'Sale', N'Return', N'Stocktake', N'Transfer', N'Adjustment')),
    Quantity      int NOT NULL CONSTRAINT CK_Ledger_Qty CHECK (Quantity > 0),
    BalanceAfter  int NOT NULL CONSTRAINT CK_Ledger_Balance CHECK (BalanceAfter >= 0),
    ReferenceType nvarchar(30) NULL,
    ReferenceId   bigint NULL,
    CreatedAt     datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_InventoryLedger PRIMARY KEY CLUSTERED (CreatedAt, LedgerId) ON ps_Ledger_Monthly (CreatedAt)
) ON ps_Ledger_Monthly (CreatedAt);

CREATE TABLE dbo.PurchaseReceipts (
    ReceiptId    bigint IDENTITY(1,1) CONSTRAINT PK_PurchaseReceipts PRIMARY KEY,
    TenantId     int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    BranchId     int NOT NULL CONSTRAINT FK_PR_Branches REFERENCES dbo.Branches(BranchId),
    SupplierName nvarchar(200) NOT NULL,
    [Status]     nvarchar(12) NOT NULL DEFAULT N'Confirmed' CONSTRAINT CK_PR_Status CHECK ([Status] IN (N'Draft', N'Confirmed')),
    CreatedAt    datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    ConfirmedAt  datetime2(3) NULL
);

CREATE TABLE dbo.PurchaseReceiptItems (
    ItemId      bigint IDENTITY(1,1) CONSTRAINT PK_PurchaseReceiptItems PRIMARY KEY,
    TenantId    int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    ReceiptId   bigint NOT NULL CONSTRAINT FK_PRI_Receipts REFERENCES dbo.PurchaseReceipts(ReceiptId),
    SKUId       int NOT NULL CONSTRAINT FK_PRI_SKUs REFERENCES dbo.SKUs(SKUId),
    Quantity    int NOT NULL CONSTRAINT CK_PRI_Qty CHECK (Quantity > 0),
    ImportPrice decimal(18,4) NOT NULL CONSTRAINT CK_PRI_Price CHECK (ImportPrice >= 0)
);

CREATE SEQUENCE dbo.seq_OrderNo AS bigint START WITH 1 INCREMENT BY 1 CACHE 100;

CREATE TABLE dbo.Orders (
    OrderId         bigint IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    TenantId        int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    BranchId        int NOT NULL CONSTRAINT FK_Orders_Branches REFERENCES dbo.Branches(BranchId),
    OrderNo         nvarchar(40) NOT NULL,
    Channel         nvarchar(20) NOT NULL CONSTRAINT CK_Orders_Channel CHECK (Channel IN (N'POS', N'Admin', N'Shopee', N'TikTok', N'Lazada')),
    [Status]        nvarchar(15) NOT NULL DEFAULT N'Draft'
                    CONSTRAINT CK_Orders_Status CHECK ([Status] IN (N'Draft', N'Reserved', N'Confirmed', N'Completed', N'Cancelled')),
    ExternalOrderId nvarchar(64) NULL,
    PaymentMethod   nvarchar(10) NULL,
    TotalAmount     decimal(18,2) NOT NULL DEFAULT 0,
    TotalCost       decimal(18,4) NOT NULL DEFAULT 0,
    CreatedBy       int NULL,
    CreatedAt       datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    ReservedAt      datetime2(3) NULL,
    ConfirmedAt     datetime2(3) NULL,
    CompletedAt     datetime2(3) NULL,
    CancelledAt     datetime2(3) NULL,
    CancelReason    nvarchar(200) NULL,
    ExpiresAt       datetime2(3) NULL,
    CONSTRAINT UQ_Orders_No UNIQUE (TenantId, OrderNo)
);

CREATE TABLE dbo.OrderItems (
    ItemId    bigint IDENTITY(1,1) CONSTRAINT PK_OrderItems PRIMARY KEY,
    TenantId  int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    OrderId   bigint NOT NULL CONSTRAINT FK_OrderItems_Orders REFERENCES dbo.Orders(OrderId),
    SKUId     int NOT NULL CONSTRAINT FK_OrderItems_SKUs REFERENCES dbo.SKUs(SKUId),
    Quantity  int NOT NULL CONSTRAINT CK_OrderItems_Qty CHECK (Quantity > 0),
    UnitPrice decimal(18,2) NOT NULL,
    CostPrice decimal(18,4) NULL,
    LineTotal decimal(18,2) NOT NULL,
    CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_OrderItems UNIQUE (OrderId, SKUId)
);

-- SỬA LỖI 10609: ExternalOrderId được định nghĩa là cột thường NULL, không dùng Computed Column
CREATE TABLE dbo.WebhookEvents (
    EventId         bigint IDENTITY(1,1) CONSTRAINT PK_WebhookEvents PRIMARY KEY,
    TenantId        int NOT NULL DEFAULT (CONVERT(int, SESSION_CONTEXT(N'TenantId'))),
    Channel         nvarchar(20) NOT NULL,
    Payload         nvarchar(max) NOT NULL CONSTRAINT CK_Webhook_Json CHECK (ISJSON(Payload) = 1),
    ExternalOrderId nvarchar(64) NULL,
    [Status]        nvarchar(12) NOT NULL DEFAULT N'Received' CONSTRAINT CK_Webhook_Status CHECK ([Status] IN (N'Received', N'Reserved', N'Rejected')),
    OrderId         bigint NULL,
    ErrorMessage    nvarchar(500) NULL,
    ReceivedAt      datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

/* ============================ 3. CHỈ MỤC ==================================== */
CREATE NONCLUSTERED INDEX IX_Ledger_Tenant_Sku_Created
    ON dbo.InventoryLedger (TenantId, SKUId, CreatedAt DESC)
    INCLUDE (BranchId, [Type], Quantity, BalanceAfter)
    ON ps_Ledger_Monthly (CreatedAt);

CREATE NONCLUSTERED INDEX IX_Ledger_Tenant_Created
    ON dbo.InventoryLedger (TenantId, CreatedAt)
    ON ps_Ledger_Monthly (CreatedAt);

CREATE NONCLUSTERED INDEX IX_Orders_Reserved
    ON dbo.Orders (TenantId, ExpiresAt) INCLUDE (BranchId)
    WHERE [Status] = N'Reserved';

CREATE NONCLUSTERED INDEX IX_Orders_Tenant_Created
    ON dbo.Orders (TenantId, CreatedAt) INCLUDE (Channel, [Status], TotalAmount, TotalCost);

CREATE UNIQUE NONCLUSTERED INDEX UX_Orders_External
    ON dbo.Orders (TenantId, Channel, ExternalOrderId) WHERE ExternalOrderId IS NOT NULL;

-- Filtered Index hoạt động hoàn hảo trên cột ExternalOrderId thông thường
CREATE UNIQUE NONCLUSTERED INDEX UX_Webhook_External
    ON dbo.WebhookEvents (TenantId, Channel, ExternalOrderId) WHERE ExternalOrderId IS NOT NULL;

CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_OrderItems_Analytics
    ON dbo.OrderItems (TenantId, OrderId, SKUId, Quantity, UnitPrice, CostPrice, LineTotal, CreatedAt);
GO

/* ====================== 4. ROW-LEVEL SECURITY =============================== */
CREATE SCHEMA sec;
GO

CREATE FUNCTION sec.fn_TenantPredicate (@TenantId int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS Allowed
       WHERE @TenantId = CONVERT(int, SESSION_CONTEXT(N'TenantId'));
GO

CREATE SECURITY POLICY sec.TenantIsolationPolicy
    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.Branches,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Branches AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Branches AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Branches BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Branches BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.Categories,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Categories AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Categories AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Categories BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Categories BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.Brands,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Brands AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Brands AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Brands BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Brands BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.Products,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Products AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Products AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Products BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Products BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.SKUs,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.SKUs AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.SKUs AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.SKUs BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.SKUs BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.ListedPrices,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.ListedPrices AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.ListedPrices AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.ListedPrices BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.ListedPrices BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.StockLevels,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.StockLevels AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.StockLevels AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.StockLevels BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.StockLevels BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.InventoryLedger,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.InventoryLedger AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.InventoryLedger AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.InventoryLedger BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.InventoryLedger BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceipts,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceipts AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceipts AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceipts BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceipts BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceiptItems,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceiptItems AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceiptItems AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceiptItems BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.PurchaseReceiptItems BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.Orders,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Orders AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Orders AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Orders BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.Orders BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.OrderItems,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.OrderItems AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.OrderItems AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.OrderItems BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.OrderItems BEFORE DELETE,

    ADD FILTER PREDICATE sec.fn_TenantPredicate(TenantId) ON dbo.WebhookEvents,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.WebhookEvents AFTER INSERT,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.WebhookEvents AFTER UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.WebhookEvents BEFORE UPDATE,
    ADD BLOCK PREDICATE  sec.fn_TenantPredicate(TenantId) ON dbo.WebhookEvents BEFORE DELETE
WITH (STATE = ON, SCHEMABINDING = ON);
GO

/* ===================== TVP (User-Defined Table Type) ======================== */
CREATE TYPE dbo.CartItemType AS TABLE (
    SKUId    int NOT NULL,
    Quantity int NOT NULL
);
CREATE TYPE dbo.ReceiptItemType AS TABLE (
    SKUId       int NOT NULL,
    Quantity    int NOT NULL,
    ImportPrice decimal(18,4) NOT NULL
);
GO

/* ============================ 5. TRIGGER ==================================== */
-- Sổ cái append-only tuyệt đối
CREATE TRIGGER dbo.trg_InventoryLedger_AppendOnly
ON dbo.InventoryLedger
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50050, N'InventoryLedger là sổ cái append-only: không được UPDATE/DELETE. Hãy ghi bút toán điều chỉnh (compensating entry).', 1;
END;
GO

-- Tính giá vốn bình quân gia quyền
CREATE TRIGGER dbo.trg_PurchaseReceiptItems_WeightedAvgCost
ON dbo.PurchaseReceiptItems
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    WITH imp AS (
        SELECT TenantId, SKUId,
               SUM(Quantity) AS ImpQty,
               SUM(CAST(Quantity AS decimal(18,4)) * ImportPrice) AS ImpValue
        FROM inserted
        GROUP BY TenantId, SKUId
    ),
    stock AS (
        SELECT s.TenantId, s.SKUId, SUM(s.OnHand) AS OldStock
        FROM dbo.StockLevels AS s
        JOIN imp ON imp.TenantId = s.TenantId AND imp.SKUId = s.SKUId
        GROUP BY s.TenantId, s.SKUId
    )
    UPDATE k
    SET CostPrice = CAST((COALESCE(st.OldStock, 0) * k.CostPrice + imp.ImpValue)
                         / (COALESCE(st.OldStock, 0) + imp.ImpQty) AS decimal(18,4))
    FROM dbo.SKUs AS k
    JOIN imp ON imp.TenantId = k.TenantId AND imp.SKUId = k.SKUId
    LEFT JOIN stock AS st ON st.TenantId = k.TenantId AND st.SKUId = k.SKUId;
END;
GO

-- State machine đơn hàng
CREATE TRIGGER dbo.trg_Orders_StateMachine
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE([Status]) RETURN;
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d ON d.OrderId = i.OrderId
        WHERE i.[Status] <> d.[Status]
          AND NOT EXISTS (
              SELECT 1
              FROM (VALUES (N'Draft', N'Reserved'), (N'Draft', N'Cancelled'),
                           (N'Reserved', N'Confirmed'), (N'Reserved', N'Cancelled'),
                           (N'Confirmed', N'Completed')) AS ok (FromStatus, ToStatus)
              WHERE ok.FromStatus = d.[Status] AND ok.ToStatus = i.[Status]))
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50030, N'Chuyển trạng thái đơn hàng không hợp lệ (Draft>Reserved>Confirmed>Completed, hoặc Cancelled).', 1;
    END;
END;
GO

/* ===================== 6. STORED PROCEDURE ================================== */
-- 6.1 Giữ hàng
CREATE PROCEDURE dbo.usp_ReserveOrder
    @BranchId        int,
    @Channel         nvarchar(20),
    @Items           dbo.CartItemType READONLY,
    @ExternalOrderId nvarchar(64) = NULL,
    @HoldMinutes     int = 30,
    @CreatedBy       int = NULL,
    @OrderId         bigint = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF CONVERT(int, SESSION_CONTEXT(N'TenantId')) IS NULL
        THROW 50001, N'Phiên làm việc chưa có TenantId trong SESSION_CONTEXT.', 1;
    IF EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0)
        THROW 50002, N'Số lượng phải lớn hơn 0.', 1;

    DECLARE @Cart TABLE (SKUId int NOT NULL PRIMARY KEY, Quantity int NOT NULL);
    INSERT @Cart (SKUId, Quantity) SELECT SKUId, SUM(Quantity) FROM @Items GROUP BY SKUId;
    IF NOT EXISTS (SELECT 1 FROM @Cart) THROW 50003, N'Giỏ hàng trống.', 1;

    DECLARE @own bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    IF @own = 1 BEGIN TRAN;

    DECLARE @Lock TABLE (SKUId int NOT NULL PRIMARY KEY, Available int NOT NULL);
    INSERT @Lock (SKUId, Available)
    SELECT c.SKUId, s.Available
    FROM @Cart AS c
    INNER LOOP JOIN dbo.StockLevels AS s WITH (UPDLOCK, ROWLOCK)
         ON s.BranchId = @BranchId AND s.SKUId = c.SKUId
    ORDER BY c.SKUId
    OPTION (FORCE ORDER);

    DECLARE @bad nvarchar(1000);
    SELECT @bad = STRING_AGG(CONCAT(k.SkuCode, N' (còn ', COALESCE(l.Available, 0), N', cần ', c.Quantity, N')'), N'; ')
    FROM @Cart AS c
    LEFT JOIN @Lock AS l ON l.SKUId = c.SKUId
    JOIN dbo.SKUs AS k ON k.SKUId = c.SKUId
    WHERE COALESCE(l.Available, 0) < c.Quantity;
    IF @bad IS NOT NULL
    BEGIN
        DECLARE @msg nvarchar(2048) = CONCAT(N'Không đủ tồn khả dụng: ', @bad);
        THROW 50010, @msg, 1;
    END;

    DECLARE @seq bigint, @OrderNo nvarchar(40);
    SELECT @seq = NEXT VALUE FOR dbo.seq_OrderNo;
    SET @OrderNo = CONCAT(UPPER(LEFT(@Channel, 3)), N'-', CONVERT(char(6), SYSUTCDATETIME(), 12), N'-', RIGHT(CONCAT(N'000000', @seq), 6));

    INSERT dbo.Orders (BranchId, OrderNo, Channel, [Status], ExternalOrderId, ExpiresAt, CreatedBy)
    VALUES (@BranchId, @OrderNo, @Channel, N'Draft', @ExternalOrderId, DATEADD(MINUTE, @HoldMinutes, SYSUTCDATETIME()), @CreatedBy);
    SET @OrderId = SCOPE_IDENTITY();

    INSERT dbo.OrderItems (OrderId, SKUId, Quantity, UnitPrice, LineTotal)
    SELECT @OrderId, c.SKUId, c.Quantity, p.RetailPrice, c.Quantity * p.RetailPrice
    FROM @Cart AS c
    JOIN dbo.ListedPrices AS p ON p.SKUId = c.SKUId;
    IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Cart)
        THROW 50011, N'Có SKU chưa có giá niêm yết.', 1;

    UPDATE s
    SET Reserved = s.Reserved + c.Quantity, UpdatedAt = SYSUTCDATETIME()
    FROM dbo.StockLevels AS s
    JOIN @Cart AS c ON c.SKUId = s.SKUId
    WHERE s.BranchId = @BranchId;

    UPDATE dbo.Orders
    SET [Status] = N'Reserved', ReservedAt = SYSUTCDATETIME(),
        TotalAmount = (SELECT SUM(LineTotal) FROM dbo.OrderItems WHERE OrderId = @OrderId)
    WHERE OrderId = @OrderId;

    IF @own = 1 COMMIT TRAN;
END;
GO

-- 6.2 Xác nhận đơn
CREATE PROCEDURE dbo.usp_ConfirmOrder
    @OrderId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @own bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    IF @own = 1 BEGIN TRAN;

    DECLARE @Status nvarchar(15), @BranchId int;
    SELECT @Status = [Status], @BranchId = BranchId
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE OrderId = @OrderId;
    IF @Status IS NULL THROW 50020, N'Không tìm thấy đơn hàng.', 1;
    IF @Status <> N'Reserved' THROW 50021, N'Chỉ xác nhận được đơn ở trạng thái Reserved.', 1;

    DECLARE @Lines TABLE (SKUId int NOT NULL PRIMARY KEY, Quantity int NOT NULL);
    INSERT @Lines (SKUId, Quantity)
    SELECT SKUId, SUM(Quantity) FROM dbo.OrderItems WHERE OrderId = @OrderId GROUP BY SKUId;

    DECLARE @Lock TABLE (SKUId int NOT NULL PRIMARY KEY, OnHand int NOT NULL);
    INSERT @Lock (SKUId, OnHand)
    SELECT l.SKUId, s.OnHand
    FROM @Lines AS l
    INNER LOOP JOIN dbo.StockLevels AS s WITH (UPDLOCK, ROWLOCK)
         ON s.BranchId = @BranchId AND s.SKUId = l.SKUId
    ORDER BY l.SKUId
    OPTION (FORCE ORDER);

    UPDATE s
    SET OnHand = s.OnHand - l.Quantity, Reserved = s.Reserved - l.Quantity, UpdatedAt = SYSUTCDATETIME()
    FROM dbo.StockLevels AS s
    JOIN @Lines AS l ON l.SKUId = s.SKUId
    WHERE s.BranchId = @BranchId;

    INSERT dbo.InventoryLedger (BranchId, SKUId, [Type], TxnType, Quantity, BalanceAfter, ReferenceType, ReferenceId)
    SELECT @BranchId, l.SKUId, 'OUT', N'Sale', l.Quantity, s.OnHand, N'Order', @OrderId
    FROM @Lines AS l
    JOIN dbo.StockLevels AS s ON s.BranchId = @BranchId AND s.SKUId = l.SKUId;

    UPDATE oi
    SET CostPrice = k.CostPrice
    FROM dbo.OrderItems AS oi
    JOIN dbo.SKUs AS k ON k.SKUId = oi.SKUId
    WHERE oi.OrderId = @OrderId;

    UPDATE dbo.Orders
    SET [Status] = N'Confirmed', ConfirmedAt = SYSUTCDATETIME(),
        TotalCost = (SELECT SUM(Quantity * CostPrice) FROM dbo.OrderItems WHERE OrderId = @OrderId)
    WHERE OrderId = @OrderId;

    IF @own = 1 COMMIT TRAN;
END;
GO

-- 6.3 Hủy đơn
CREATE PROCEDURE dbo.usp_CancelOrder
    @OrderId bigint,
    @Reason  nvarchar(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @own bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    IF @own = 1 BEGIN TRAN;

    DECLARE @Status nvarchar(15), @BranchId int;
    SELECT @Status = [Status], @BranchId = BranchId
    FROM dbo.Orders WITH (UPDLOCK, ROWLOCK) WHERE OrderId = @OrderId;
    IF @Status IS NULL THROW 50020, N'Không tìm thấy đơn hàng.', 1;
    IF @Status NOT IN (N'Draft', N'Reserved') THROW 50022, N'Chỉ hủy được đơn Draft hoặc Reserved.', 1;

    IF @Status = N'Reserved'
    BEGIN
        DECLARE @Lines TABLE (SKUId int NOT NULL PRIMARY KEY, Quantity int NOT NULL);
        INSERT @Lines (SKUId, Quantity)
        SELECT SKUId, SUM(Quantity) FROM dbo.OrderItems WHERE OrderId = @OrderId GROUP BY SKUId;

        DECLARE @Lock TABLE (SKUId int NOT NULL PRIMARY KEY, Reserved int NOT NULL);
        INSERT @Lock (SKUId, Reserved)
        SELECT l.SKUId, s.Reserved
        FROM @Lines AS l
        INNER LOOP JOIN dbo.StockLevels AS s WITH (UPDLOCK, ROWLOCK)
             ON s.BranchId = @BranchId AND s.SKUId = l.SKUId
        ORDER BY l.SKUId
        OPTION (FORCE ORDER);

        UPDATE s
        SET Reserved = s.Reserved - l.Quantity, UpdatedAt = SYSUTCDATETIME()
        FROM dbo.StockLevels AS s
        JOIN @Lines AS l ON l.SKUId = s.SKUId
        WHERE s.BranchId = @BranchId;
    END;

    UPDATE dbo.Orders
    SET [Status] = N'Cancelled', CancelledAt = SYSUTCDATETIME(), CancelReason = @Reason
    WHERE OrderId = @OrderId;

    IF @own = 1 COMMIT TRAN;
END;
GO

CREATE PROCEDURE dbo.usp_CompleteOrder
    @OrderId bigint
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    UPDATE dbo.Orders SET [Status] = N'Completed', CompletedAt = SYSUTCDATETIME() WHERE OrderId = @OrderId;
    IF @@ROWCOUNT = 0 THROW 50020, N'Không tìm thấy đơn hàng.', 1;
END;
GO

-- 6.4 Fast Checkout
CREATE PROCEDURE dbo.usp_FastCheckout
    @BranchId      int,
    @PaymentMethod nvarchar(10),
    @Items         dbo.CartItemType READONLY,
    @CashierId     int = NULL,
    @OrderId       bigint = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @PaymentMethod NOT IN (N'Cash', N'QR') THROW 50060, N'Phương thức thanh toán không hợp lệ (Cash hoặc QR).', 1;

    BEGIN TRAN;
        EXEC dbo.usp_ReserveOrder @BranchId = @BranchId, @Channel = N'POS', @Items = @Items,
                                  @CreatedBy = @CashierId, @OrderId = @OrderId OUTPUT;
        EXEC dbo.usp_ConfirmOrder @OrderId = @OrderId;
        UPDATE dbo.Orders
        SET [Status] = N'Completed', CompletedAt = SYSUTCDATETIME(), PaymentMethod = @PaymentMethod
        WHERE OrderId = @OrderId;
    COMMIT TRAN;

    SELECT OrderId, OrderNo, [Status], TotalAmount, TotalCost, TotalAmount - TotalCost AS GrossProfit
    FROM dbo.Orders WHERE OrderId = @OrderId;
END;
GO

-- 6.5 Nhập hàng
CREATE PROCEDURE dbo.usp_ConfirmPurchaseReceipt
    @BranchId     int,
    @SupplierName nvarchar(200),
    @Items        dbo.ReceiptItemType READONLY,
    @ReceiptId    bigint = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0 OR ImportPrice < 0)
        THROW 50080, N'Số lượng phải > 0 và giá nhập phải >= 0.', 1;

    DECLARE @Agg TABLE (SKUId int NOT NULL PRIMARY KEY, Qty int NOT NULL);
    INSERT @Agg (SKUId, Qty) SELECT SKUId, SUM(Quantity) FROM @Items GROUP BY SKUId;

    DECLARE @own bit = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    IF @own = 1 BEGIN TRAN;

    INSERT dbo.PurchaseReceipts (BranchId, SupplierName, [Status], ConfirmedAt)
    VALUES (@BranchId, @SupplierName, N'Confirmed', SYSUTCDATETIME());
    SET @ReceiptId = SCOPE_IDENTITY();

    INSERT dbo.PurchaseReceiptItems (ReceiptId, SKUId, Quantity, ImportPrice)
    SELECT @ReceiptId, SKUId, Quantity, ImportPrice FROM @Items ORDER BY SKUId;

    INSERT dbo.StockLevels (BranchId, SKUId)
    SELECT @BranchId, a.SKUId
    FROM @Agg AS a
    WHERE NOT EXISTS (SELECT 1 FROM dbo.StockLevels AS s WITH (UPDLOCK, HOLDLOCK)
                      WHERE s.BranchId = @BranchId AND s.SKUId = a.SKUId);

    UPDATE s
    SET OnHand = s.OnHand + a.Qty, UpdatedAt = SYSUTCDATETIME()
    FROM dbo.StockLevels AS s WITH (UPDLOCK, ROWLOCK)
    JOIN @Agg AS a ON a.SKUId = s.SKUId
    WHERE s.BranchId = @BranchId;

    INSERT dbo.InventoryLedger (BranchId, SKUId, [Type], TxnType, Quantity, BalanceAfter, ReferenceType, ReferenceId)
    SELECT @BranchId, a.SKUId, 'IN', N'Import', a.Qty, s.OnHand, N'PurchaseReceipt', @ReceiptId
    FROM @Agg AS a
    JOIN dbo.StockLevels AS s ON s.BranchId = @BranchId AND s.SKUId = a.SKUId;

    IF @own = 1 COMMIT TRAN;
END;
GO

-- 6.6 Kiểm kê kho
CREATE PROCEDURE dbo.usp_StocktakeAdjust
    @BranchId   int,
    @SKUId      int,
    @CountedQty int
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @CountedQty < 0 THROW 50070, N'Số lượng kiểm đếm không được âm.', 1;

    BEGIN TRAN;
        DECLARE @OnHand int, @Reserved int;
        SELECT @OnHand = OnHand, @Reserved = Reserved
        FROM dbo.StockLevels WITH (UPDLOCK, ROWLOCK)
        WHERE BranchId = @BranchId AND SKUId = @SKUId;
        IF @OnHand IS NULL THROW 50071, N'SKU chưa có tồn tại chi nhánh này.', 1;
        IF @CountedQty < @Reserved THROW 50072, N'Số kiểm đếm nhỏ hơn số lượng đang giữ chỗ (reserved).', 1;

        DECLARE @Delta int = @CountedQty - @OnHand;
        IF @Delta <> 0
        BEGIN
            UPDATE dbo.StockLevels SET OnHand = @CountedQty, UpdatedAt = SYSUTCDATETIME()
            WHERE BranchId = @BranchId AND SKUId = @SKUId;

            INSERT dbo.InventoryLedger (BranchId, SKUId, [Type], TxnType, Quantity, BalanceAfter, ReferenceType)
            VALUES (@BranchId, @SKUId, CASE WHEN @Delta > 0 THEN 'IN' ELSE 'OUT' END, N'Stocktake',
                    ABS(@Delta), @CountedQty, N'Stocktake');
        END;
    COMMIT TRAN;
END;
GO

-- 6.7 Webhook Sàn TMĐT
CREATE PROCEDURE dbo.usp_IngestWebhook
    @BranchId int,
    @Channel  nvarchar(20),
    @Payload  nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF ISJSON(@Payload, OBJECT) <> 1 THROW 50040, N'Payload không phải JSON object.', 1;

    DECLARE @EventId bigint, @OrderId bigint;
    DECLARE @Ext nvarchar(64) = JSON_VALUE(@Payload, N'$.order_sn');

    INSERT dbo.WebhookEvents (Channel, Payload, ExternalOrderId) VALUES (@Channel, @Payload, @Ext);
    SET @EventId = SCOPE_IDENTITY();

    DECLARE @Items dbo.CartItemType;
    BEGIN TRY
        INSERT @Items (SKUId, Quantity)
        SELECT k.SKUId, j.qty
        FROM OPENJSON(@Payload, N'$.items')
             WITH (sku nvarchar(50) N'$.sku', qty int N'$.qty') AS j
        JOIN dbo.SKUs AS k ON k.SkuCode = j.sku;

        IF (SELECT COUNT(*) FROM OPENJSON(@Payload, N'$.items')) <> (SELECT COUNT(*) FROM @Items)
            THROW 50041, N'Payload chứa SKU không tồn tại.', 1;

        EXEC dbo.usp_ReserveOrder @BranchId = @BranchId, @Channel = @Channel, @Items = @Items,
                                  @ExternalOrderId = @Ext, @OrderId = @OrderId OUTPUT;
        UPDATE dbo.WebhookEvents SET [Status] = N'Reserved', OrderId = @OrderId WHERE EventId = @EventId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        UPDATE dbo.WebhookEvents
        SET [Status] = N'Rejected', ErrorMessage = LEFT(ERROR_MESSAGE(), 500)
        WHERE EventId = @EventId;
    END CATCH;

    SELECT EventId, Channel, ExternalOrderId, [Status], OrderId, ErrorMessage
    FROM dbo.WebhookEvents WHERE EventId = @EventId;
END;
GO

-- 6.8 Job quét quá hạn
CREATE PROCEDURE dbo.usp_ExpireReservedOrders
    @BatchSize int = 50
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Expired TABLE (OrderId bigint NOT NULL PRIMARY KEY, BranchId int NOT NULL, OldStatus nvarchar(15) NOT NULL);
    DECLARE @attempt int = 0, @done bit = 0;

    WHILE @done = 0
    BEGIN
        BEGIN TRY
            DELETE FROM @Expired;
            BEGIN TRAN;
                UPDATE TOP (@BatchSize) o
                SET [Status] = N'Cancelled', CancelledAt = SYSUTCDATETIME(), CancelReason = N'Hết hạn giữ hàng'
                OUTPUT inserted.OrderId, inserted.BranchId, deleted.[Status] INTO @Expired (OrderId, BranchId, OldStatus)
                FROM dbo.Orders AS o WITH (UPDLOCK, READPAST, ROWLOCK)
                WHERE o.[Status] IN (N'Draft', N'Reserved') AND o.ExpiresAt < SYSUTCDATETIME();

                UPDATE s
                SET Reserved = s.Reserved - x.Qty, UpdatedAt = SYSUTCDATETIME()
                FROM dbo.StockLevels AS s
                JOIN (SELECT e.BranchId, oi.SKUId, SUM(oi.Quantity) AS Qty
                      FROM @Expired AS e
                      JOIN dbo.OrderItems AS oi ON oi.OrderId = e.OrderId
                      WHERE e.OldStatus = N'Reserved'
                      GROUP BY e.BranchId, oi.SKUId) AS x
                  ON x.BranchId = s.BranchId AND x.SKUId = s.SKUId;
            COMMIT TRAN;
            SET @done = 1;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            IF ERROR_NUMBER() = 1205 AND @attempt < 2
            BEGIN
                SET @attempt += 1;
                WAITFOR DELAY '00:00:00.100';
            END
            ELSE THROW;
        END CATCH;
    END;

    SELECT COUNT(*) AS CancelledOrders FROM @Expired;
END;
GO

/* ================== 7. BÁO CÁO, CẢNH BÁO, PHÂN QUYỀN ======================== */
CREATE VIEW dbo.vw_StockAlerts
AS
SELECT s.TenantId, s.BranchId, s.SKUId, k.SkuCode, s.OnHand, s.Reserved, s.Available, k.ReorderThreshold
FROM dbo.StockLevels AS s
JOIN dbo.SKUs AS k ON k.SKUId = s.SKUId
WHERE s.Available <= k.ReorderThreshold;
GO

CREATE PROCEDURE dbo.usp_RevenueReport
    @From     datetime2(3),
    @To       datetime2(3),
    @BranchId int = NULL,
    @Channel  nvarchar(20) = NULL,
    @SKUId    int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(o.ConfirmedAt AS date) AS [Day],
           o.Channel,
           SUM(oi.LineTotal)                                 AS NetRevenue,
           SUM(oi.Quantity * oi.CostPrice)                   AS TotalCOGS,
           SUM(oi.LineTotal - oi.Quantity * oi.CostPrice)    AS GrossProfit
    FROM dbo.OrderItems AS oi
    JOIN dbo.Orders AS o ON o.OrderId = oi.OrderId
    WHERE o.[Status] IN (N'Confirmed', N'Completed')
      AND o.ConfirmedAt >= @From AND o.ConfirmedAt < @To
      AND (@BranchId IS NULL OR o.BranchId = @BranchId)
      AND (@Channel  IS NULL OR o.Channel  = @Channel)
      AND (@SKUId    IS NULL OR oi.SKUId   = @SKUId)
    GROUP BY CAST(o.ConfirmedAt AS date), o.Channel
    ORDER BY [Day], o.Channel;
END;
GO

CREATE ROLE oism_app;
GRANT SELECT  ON SCHEMA::dbo TO oism_app;
GRANT EXECUTE ON SCHEMA::dbo TO oism_app;
GRANT EXECUTE ON TYPE::dbo.CartItemType    TO oism_app;
GRANT EXECUTE ON TYPE::dbo.ReceiptItemType TO oism_app;
GRANT INSERT, UPDATE ON dbo.Branches   TO oism_app;
GRANT INSERT, UPDATE ON dbo.Categories TO oism_app;
GRANT INSERT, UPDATE ON dbo.Brands     TO oism_app;
GRANT INSERT, UPDATE ON dbo.Products   TO oism_app;
GRANT INSERT, UPDATE ON dbo.SKUs       TO oism_app;
GRANT INSERT, UPDATE ON dbo.ListedPrices TO oism_app;
DENY UPDATE (CostPrice) ON dbo.SKUs TO oism_app;
DENY INSERT, UPDATE, DELETE ON dbo.StockLevels     TO oism_app;
DENY UPDATE, DELETE         ON dbo.InventoryLedger TO oism_app;
GO

/* ============================ 8. DỮ LIỆU MẪU ================================ */
DECLARE @T1 int, @T2 int, @T3 int;
INSERT dbo.Tenants (Name) VALUES (N'Cửa hàng Minh Anh');  SET @T1 = SCOPE_IDENTITY();
INSERT dbo.Tenants (Name) VALUES (N'Shop Hoa Sen');       SET @T2 = SCOPE_IDENTITY();
INSERT dbo.Tenants (Name) VALUES (N'Tenant load test');   SET @T3 = SCOPE_IDENTITY();

INSERT dbo.Users (TenantId, FullName, Email, Phone, PasswordHash, [Role]) VALUES
 (@T1, N'Nguyễn Minh Anh', N'owner@minhanh.vn',   N'0901000001', N'$2a$11$DEMO.HASH.THAY.BANG.BCRYPT.TU.API', N'Owner'),
 (@T1, N'Trần Quốc Bảo',   N'kho@minhanh.vn',     N'0901000002', N'$2a$11$DEMO.HASH.THAY.BANG.BCRYPT.TU.API', N'Staff'),
 (@T1, N'Lê Thu Hà',       N'thungan@minhanh.vn', N'0901000003', N'$2a$11$DEMO.HASH.THAY.BANG.BCRYPT.TU.API', N'Cashier'),
 (@T2, N'Phạm Hoa Sen',    N'owner@hoasen.vn',    N'0902000001', N'$2a$11$DEMO.HASH.THAY.BANG.BCRYPT.TU.API', N'Owner');

-- Tenant 1
EXEC sys.sp_set_session_context @key = N'TenantId', @value = @T1;

INSERT dbo.Branches (Name, Address) VALUES
 (N'Chi nhánh Quận 1', N'12 Lê Lợi, Quận 1, TP.HCM'),
 (N'Kho Thủ Đức',      N'88 Võ Văn Ngân, TP. Thủ Đức');

INSERT dbo.Categories (Name) VALUES (N'Thời trang'), (N'Phụ kiện');
INSERT dbo.Categories (ParentId, Name)
SELECT CategoryId, N'Áo' FROM dbo.Categories WHERE Name = N'Thời trang';

INSERT dbo.Brands (Name) VALUES (N'Saigon Wear'), (N'Urban Lab');

INSERT dbo.Products (CategoryId, BrandId, Name)
SELECT c.CategoryId, b.BrandId, v.Name
FROM (VALUES (N'Áo',        N'Saigon Wear', N'Áo thun cotton basic'),
             (N'Thời trang', N'Saigon Wear', N'Quần jean slim'),
             (N'Thời trang', N'Urban Lab',   N'Giày sneaker trắng'),
             (N'Phụ kiện',   N'Urban Lab',   N'Tai nghe Bluetooth bản giới hạn')) AS v (Cat, Brand, Name)
JOIN dbo.Categories AS c ON c.Name = v.Cat
JOIN dbo.Brands AS b ON b.Name = v.Brand;

INSERT dbo.SKUs (ProductId, SkuCode, VariantName, Barcode, ReorderThreshold)
SELECT p.ProductId, v.Code, v.Variant, v.Barcode, v.Th
FROM (VALUES (N'Áo thun cotton basic',  N'AO-THUN-DEN-M',    N'Đen / M',      N'8934000000017', 10),
             (N'Áo thun cotton basic',  N'AO-THUN-DEN-L',    N'Đen / L',      N'8934000000024', 10),
             (N'Áo thun cotton basic',  N'AO-THUN-TRANG-M',  N'Trắng / M',    N'8934000000031', 10),
             (N'Quần jean slim',        N'QUAN-JEAN-XANH-30',N'Xanh / 30',    N'8934000000048',  5),
             (N'Giày sneaker trắng',    N'GIAY-SNK-TRANG-42',N'Trắng / 42',   N'8934000000055',  3),
             (N'Tai nghe Bluetooth bản giới hạn', N'FLASH-001', N'Mặc định',  N'8934000000062',  0)) AS v (Prod, Code, Variant, Barcode, Th)
JOIN dbo.Products AS p ON p.Name = v.Prod;

INSERT dbo.ListedPrices (SKUId, RetailPrice, WholesalePrice)
SELECT k.SKUId, v.R, v.W
FROM (VALUES (N'AO-THUN-DEN-M', 149000, 119000), (N'AO-THUN-DEN-L', 149000, 119000),
             (N'AO-THUN-TRANG-M', 139000, 109000), (N'QUAN-JEAN-XANH-30', 399000, 329000),
             (N'GIAY-SNK-TRANG-42', 690000, 590000), (N'FLASH-001', 99000, 79000)) AS v (Code, R, W)
JOIN dbo.SKUs AS k ON k.SkuCode = v.Code;

DECLARE @R dbo.ReceiptItemType, @RId bigint, @Br1 int = (SELECT TOP 1 BranchId FROM dbo.Branches WHERE Name = N'Chi nhánh Quận 1');
INSERT @R (SKUId, Quantity, ImportPrice)
SELECT k.SKUId, v.Q, v.P
FROM (VALUES (N'AO-THUN-DEN-M', 50, 80000), (N'AO-THUN-DEN-L', 40, 80000), (N'AO-THUN-TRANG-M', 30, 78000),
             (N'QUAN-JEAN-XANH-30', 25, 210000), (N'GIAY-SNK-TRANG-42', 15, 380000), (N'FLASH-001', 1, 60000)) AS v (Code, Q, P)
JOIN dbo.SKUs AS k ON k.SkuCode = v.Code;
EXEC dbo.usp_ConfirmPurchaseReceipt @BranchId = @Br1, @SupplierName = N'Công ty May Sài Gòn', @Items = @R, @ReceiptId = @RId OUTPUT;

DELETE @R;
INSERT @R (SKUId, Quantity, ImportPrice) SELECT SKUId, 30, 95000 FROM dbo.SKUs WHERE SkuCode = N'AO-THUN-DEN-M';
EXEC dbo.usp_ConfirmPurchaseReceipt @BranchId = @Br1, @SupplierName = N'Công ty May Sài Gòn', @Items = @R, @ReceiptId = @RId OUTPUT;

-- Tenant 2
EXEC sys.sp_set_session_context @key = N'TenantId', @value = @T2;
INSERT dbo.Branches (Name, Address) VALUES (N'Cửa hàng Đà Lạt', N'5 Phan Đình Phùng, Đà Lạt');
INSERT dbo.Products (Name) VALUES (N'Nến thơm lavender'), (N'Xà phòng handmade bạc hà');
INSERT dbo.SKUs (ProductId, SkuCode, VariantName, Barcode, ReorderThreshold)
SELECT p.ProductId, v.Code, v.Variant, v.Barcode, 3
FROM (VALUES (N'Nến thơm lavender', N'FLASH-001', N'Hộp 200g', N'8935000000019'),
             (N'Xà phòng handmade bạc hà', N'XP-BAC-HA', N'Bánh 100g', N'8935000000026')) AS v (Prod, Code, Variant, Barcode)
JOIN dbo.Products AS p ON p.Name = v.Prod;

INSERT dbo.ListedPrices (SKUId, RetailPrice, WholesalePrice)
SELECT SKUId, CASE SkuCode WHEN N'FLASH-001' THEN 129000 ELSE 45000 END, CASE SkuCode WHEN N'FLASH-001' THEN 99000 ELSE 35000 END FROM dbo.SKUs;
DELETE @R;
INSERT @R (SKUId, Quantity, ImportPrice)
SELECT SKUId, CASE SkuCode WHEN N'FLASH-001' THEN 5 ELSE 60 END, CASE SkuCode WHEN N'FLASH-001' THEN 70000 ELSE 22000 END FROM dbo.SKUs;
DECLARE @Br2 int = (SELECT TOP 1 BranchId FROM dbo.Branches);
EXEC dbo.usp_ConfirmPurchaseReceipt @BranchId = @Br2, @SupplierName = N'Xưởng nến Đà Lạt', @Items = @R, @ReceiptId = @RId OUTPUT;

EXEC sys.sp_set_session_context @key = N'TenantId', @value = NULL;
PRINT N'ĐÃ NẠP XONG DỮ LIỆU MẪU THÀNH CÔNG!';
GO

/* ============================ 9. KIỂM THỬ ================================== */
-- T1. Kiểm tra RLS
DECLARE @T1 int = (SELECT TOP 1 TenantId FROM dbo.Tenants WHERE Name = N'Cửa hàng Minh Anh');
DECLARE @T2 int = (SELECT TOP 1 TenantId FROM dbo.Tenants WHERE Name = N'Shop Hoa Sen');

EXEC sys.sp_set_session_context N'TenantId', NULL;
SELECT N'Chưa đặt TenantId' AS Phien, COUNT(*) AS SoSKU FROM dbo.SKUs;
EXEC sys.sp_set_session_context N'TenantId', @T1;
SELECT N'Tenant 1' AS Phien, COUNT(*) AS SoSKU FROM dbo.SKUs;
EXEC sys.sp_set_session_context N'TenantId', @T2;
SELECT N'Tenant 2' AS Phien, COUNT(*) AS SoSKU FROM dbo.SKUs;
GO

-- T2. Kiểm tra Trigger Append-Only
DECLARE @T1 int = (SELECT TOP 1 TenantId FROM dbo.Tenants WHERE Name = N'Cửa hàng Minh Anh');
EXEC sys.sp_set_session_context N'TenantId', @T1;
BEGIN TRY
    UPDATE dbo.InventoryLedger SET Quantity = 999 WHERE TenantId = @T1;
    PRINT N'LỖI: UPDATE không được phép thành công';
END TRY
BEGIN CATCH
    PRINT N'T2 OK, UPDATE bị Trigger chặn thành công: ' + ERROR_MESSAGE();
END CATCH;
GO

-- T3. Kiểm tra Tính giá vốn bình quân gia quyền
DECLARE @T1 int = (SELECT TOP 1 TenantId FROM dbo.Tenants WHERE Name = N'Cửa hàng Minh Anh');
EXEC sys.sp_set_session_context N'TenantId', @T1;
SELECT SkuCode, CostPrice AS GiaVonHienTai FROM dbo.SKUs WHERE SkuCode = N'AO-THUN-DEN-M';
GO

-- T4. Kiểm tra Chống bán âm kho (Fast Checkout)
-- T4. Kiểm tra Chống bán âm kho (Fast Checkout)
DECLARE @T1 int = (SELECT TOP 1 TenantId FROM dbo.Tenants WHERE Name = N'Cửa hàng Minh Anh');
EXEC sys.sp_set_session_context N'TenantId', @T1;
DECLARE @Br1 int = (SELECT TOP 1 BranchId FROM dbo.Branches WHERE Name = N'Chi nhánh Quận 1');
DECLARE @Cart dbo.CartItemType, @O bigint;
INSERT @Cart (SKUId, Quantity) SELECT SKUId, 1 FROM dbo.SKUs WHERE SkuCode = N'FLASH-001';

-- Khách 1 mua thành công
EXEC dbo.usp_FastCheckout @BranchId = @Br1, @PaymentMethod = N'Cash', @Items = @Cart, @OrderId = @O OUTPUT;
PRINT N'T4: Khách 1 mua thành công.';

-- Khách 2 mua sẽ bị chặn (Hết tồn kho)
BEGIN TRY
    EXEC dbo.usp_FastCheckout @BranchId = @Br1, @PaymentMethod = N'Cash', @Items = @Cart, @OrderId = @O OUTPUT;
    PRINT N'LỖI: Khách 2 không được phép mua';
END TRY
BEGIN CATCH
    -- THÊM DÒNG NÀY ĐỂ ĐÓNG TRANSACTION NGAY KHI BẮT ĐƯỢC LỖI:
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

    PRINT N'T4 OK, Khách 2 bị chặn thành công: ' + ERROR_MESSAGE();
END CATCH;
GO