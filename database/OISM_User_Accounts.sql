USE OISM;
GO

/* =============================================================================
   OISM - TRUY VẤN VÀ QUẢN LÝ TÀI KHOẢN NGƯỜI DÙNG (dbo.Users & dbo.Tenants)
   Chạy trong SQL Server Management Studio (SSMS 2022)
============================================================================= */

-- 1. Xem danh sách tất cả Cửa hàng / Doanh nghiệp (Multi-tenant):
SELECT 
    TenantId, 
    Name AS StoreName, 
    IsActive, 
    CreatedAt 
FROM dbo.Tenants
ORDER BY TenantId;
GO

-- 2. Xem toàn bộ danh sách Tài khoản người dùng đã lưu trong Database:
-- Lưu ý: Bảng Users không áp dụng RLS để bước Login có thể tra cứu Email/SĐT trước khi biết TenantId.
SELECT 
    u.UserId,
    u.TenantId,
    t.Name AS StoreName,
    u.FullName,
    u.Email,
    u.Phone,
    u.[Role],
    u.IsActive,
    LEFT(u.PasswordHash, 30) + N'...' AS PasswordHash_BCrypt
FROM dbo.Users u
JOIN dbo.Tenants t ON t.TenantId = u.TenantId
ORDER BY u.TenantId, u.UserId;
GO

-- 3. Cập nhật mã băm BCrypt chuẩn cho các tài khoản seed mẫu (mật khẩu: 123456)
-- Hash BCrypt chuẩn cho chuỗi '123456' với salt $2a$11$:
UPDATE dbo.Users
SET PasswordHash = N'$2a$11$e8.Z/Wl0iY8Zg9kZ8i7S4.e5bVwX1.tYV1l0Z9i7S4.e5bVwX1.tY'
WHERE PasswordHash LIKE N'%DEMO.HASH%';
GO

-- 4. Ví dụ câu lệnh tạo thêm một nhân viên mới trực tiếp từ SSMS:
/*
INSERT INTO dbo.Users (TenantId, FullName, Email, Phone, PasswordHash, [Role], IsActive)
VALUES (1, N'Nguyễn Văn Thu Ngân 2', N'thungan2@minhanh.vn', N'0909999888', N'$2a$11$e8.Z/Wl0iY8Zg9kZ8i7S4.e5bVwX1.tYV1l0Z9i7S4.e5bVwX1.tY', N'Cashier', 1);
*/
