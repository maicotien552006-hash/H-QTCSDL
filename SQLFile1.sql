USE OISM;

-- 1. KHAI BÁO BẠN ĐANG ĐỨNG DƯỚI TƯ CÁCH TENANT 1 (CỬA HÀNG MINH ANH):
EXEC sys.sp_set_session_context @key = N'TenantId', @value = 1;

-- 2. BÂY GIỜ CHẠY LẠI CÁC CÂU LỆNH, DỮ LIỆU SẼ XUẤT HIỆN NGAY:
SELECT TOP (5) OrderId, OrderNo, Channel, Status, TotalAmount, CreatedAt
FROM dbo.Orders
ORDER BY CreatedAt DESC;

SELECT TOP (5) LedgerId, SKUId, Type, TxnType, Quantity, BalanceAfter, CreatedAt
FROM dbo.InventoryLedger
ORDER BY CreatedAt DESC;

SELECT * FROM dbo.StockLevels;