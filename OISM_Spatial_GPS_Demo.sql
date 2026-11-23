USE OISM;
GO

/* =============================================================================
   OISM - MẠNG LƯỚI GPS VÀ TRUY VẤN KHÔNG GIAN TOÀN QUỐC (SQL SERVER SPATIAL 2022)
   Hỗ trợ lưu trữ điểm ghim (GeoPins) và chi nhánh (Branches) với kiểu dữ liệu geography (SRID 4326)
============================================================================= */

-- 1. ĐẢM BẢO BẢNG dbo.Branches CÓ CỘT TỌA ĐỘ VÀ KHÔNG GIAN (geography):
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Branches') AND name = 'Latitude')
BEGIN
    ALTER TABLE dbo.Branches ADD Latitude decimal(9,6) NULL, Longitude decimal(9,6) NULL;
    PRINT N'Đã thêm cột Latitude và Longitude vào bảng dbo.Branches.';
END;
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Branches') AND name = 'GeoLocation')
BEGIN
    ALTER TABLE dbo.Branches ADD GeoLocation geography NULL;
    PRINT N'Đã thêm cột GeoLocation (geography) vào bảng dbo.Branches.';
END;
GO

-- 2. TẠO BẢNG CSDL dbo.GeoPins ĐỂ LƯU TRỮ VĨNH VIỄN CÁC ĐỊA ĐIỂM ĐƯỢC GHIM TỪ BẢN ĐỒ:
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'GeoPins')
BEGIN
    CREATE TABLE dbo.GeoPins (
        PinId       int IDENTITY(1,1) PRIMARY KEY,
        TenantId    int NOT NULL,
        Title       nvarchar(150) NOT NULL,
        Address     nvarchar(255) NULL,
        Category    nvarchar(50) DEFAULT N'Điểm ghim bản đồ',
        Latitude    decimal(9,6) NOT NULL,
        Longitude   decimal(9,6) NOT NULL,
        GeoLocation geography NULL,
        Notes       nvarchar(255) NULL,
        CreatedAt   datetime2 DEFAULT SYSUTCDATETIME()
    );
    PRINT N'Đã tạo bảng dbo.GeoPins để lưu trữ các điểm ghim GPS vào CSDL.';
END;
GO

-- 3. STORED PROCEDURE: LƯU HOẶC CẬP NHẬT ĐIỂM GHIM VÀO CƠ SỞ DỮ LIỆU
CREATE OR ALTER PROCEDURE dbo.usp_SaveGeoPin
    @TenantId  int,
    @Title     nvarchar(150),
    @Address   nvarchar(255) = NULL,
    @Category  nvarchar(50)  = N'Điểm ghim bản đồ',
    @Latitude  decimal(9,6),
    @Longitude decimal(9,6),
    @Notes     nvarchar(255) = NULL,
    @NewPinId  int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Tự động chuyển đổi Lat, Lng thành đối tượng không gian geography chuẩn WGS84
    DECLARE @Geo geography = geography::Point(@Latitude, @Longitude, 4326);

    INSERT INTO dbo.GeoPins (TenantId, Title, Address, Category, Latitude, Longitude, GeoLocation, Notes)
    VALUES (@TenantId, @Title, @Address, @Category, @Latitude, @Longitude, @Geo, @Notes);

    SET @NewPinId = SCOPE_IDENTITY();
END;
GO

-- 4. CẬP NHẬT TỌA ĐỘ GPS CHUẨN CHO TOÀN BỘ 11 HUB TRÊN KHẮP VIỆT NAM:
EXEC sys.sp_set_session_context @key=N'TenantId', @value=1;
GO

-- Miền Nam
UPDATE dbo.Branches SET Latitude = 10.7769, Longitude = 106.7009 WHERE Name LIKE N'%Quận 1%';
UPDATE dbo.Branches SET Latitude = 10.8504, Longitude = 106.7719 WHERE Name LIKE N'%Thủ Đức%';
UPDATE dbo.Branches SET Latitude = 10.0452, Longitude = 105.7469 WHERE Name LIKE N'%Cần Thơ%';
UPDATE dbo.Branches SET Latitude = 10.2289, Longitude = 103.9572 WHERE Name LIKE N'%Phú Quốc%';

-- Miền Bắc
UPDATE dbo.Branches SET Latitude = 21.0285, Longitude = 105.8542 WHERE Name LIKE N'%Hà Nội%';
UPDATE dbo.Branches SET Latitude = 20.8449, Longitude = 106.6881 WHERE Name LIKE N'%Hải Phòng%';
UPDATE dbo.Branches SET Latitude = 22.3364, Longitude = 103.8438 WHERE Name LIKE N'%Sa Pa%';

-- Miền Trung & Tây Nguyên
UPDATE dbo.Branches SET Latitude = 16.0544, Longitude = 108.2022 WHERE Name LIKE N'%Đà Nẵng%';
UPDATE dbo.Branches SET Latitude = 16.4637, Longitude = 107.5909 WHERE Name LIKE N'%Huế%';
UPDATE dbo.Branches SET Latitude = 12.2388, Longitude = 109.1967 WHERE Name LIKE N'%Nha Trang%';
UPDATE dbo.Branches SET Latitude = 11.9404, Longitude = 108.4583 WHERE Name LIKE N'%Đà Lạt%';
GO

-- Đồng bộ đối tượng geography::Point(Lat, Lng, 4326):
UPDATE dbo.Branches 
SET GeoLocation = geography::Point(Latitude, Longitude, 4326)
WHERE Latitude IS NOT NULL AND Longitude IS NOT NULL;
GO

-- 5. TRUY VẤN SPATIAL: Tính khoảng cách liên tỉnh toàn quốc (STDistance):
DECLARE @Hub_HaNoi   geography = geography::Point(21.0285, 105.8542, 4326);
DECLARE @Hub_DaNang  geography = geography::Point(16.0544, 108.2022, 4326);
DECLARE @Hub_TPHCM   geography = geography::Point(10.7769, 106.7009, 4326);

SELECT 
    N'Hà Nội ➔ Đà Nẵng' AS Tuyen_Duong,
    ROUND(@Hub_HaNoi.STDistance(@Hub_DaNang) / 1000.0, 2) AS Khoang_Cach_Bay_Km,
    ROUND((@Hub_HaNoi.STDistance(@Hub_DaNang) / 1000.0) * 1.35, 1) AS Duong_Bo_Uoc_Tinh_Km,
    N'~14 - 16 giờ' AS Thoi_Gian_Xe_Tai;

SELECT 
    N'Đà Nẵng ➔ TP.HCM' AS Tuyen_Duong,
    ROUND(@Hub_DaNang.STDistance(@Hub_TPHCM) / 1000.0, 2) AS Khoang_Cach_Bay_Km,
    ROUND((@Hub_DaNang.STDistance(@Hub_TPHCM) / 1000.0) * 1.3, 1) AS Duong_Bo_Uoc_Tinh_Km,
    N'~16 - 18 giờ' AS Thoi_Gian_Xe_Tai;

SELECT 
    N'Hà Nội ➔ TP.HCM (Xuyên Việt)' AS Tuyen_Duong,
    ROUND(@Hub_HaNoi.STDistance(@Hub_TPHCM) / 1000.0, 2) AS Khoang_Cach_Bay_Km,
    ROUND((@Hub_HaNoi.STDistance(@Hub_TPHCM) / 1000.0) * 1.4, 1) AS Duong_Bo_Uoc_Tinh_Km,
    N'~32 - 36 giờ' AS Thoi_Gian_Xe_Tai;
GO

-- 6. XEM DANH SÁCH ĐIỂM GHIM TRONG CƠ SỞ DỮ LIỆU:
SELECT 
    PinId,
    TenantId,
    Title,
    Address,
    Category,
    Latitude,
    Longitude,
    CreatedAt
FROM dbo.GeoPins
ORDER BY PinId DESC;
GO
