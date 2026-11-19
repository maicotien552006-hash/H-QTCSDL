# ==============================================================================
# OISM Backend .NET 8 Web API Dockerfile (Multi-stage build)
# ==============================================================================

# Stage 1: Build & Publish
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Sao chep tep du an va khoi phuc NuGet dependencies
COPY ["backend.csproj", "./"]
RUN dotnet restore "backend.csproj"

# Sao chep toan bo ma nguon va bien dich Release
COPY . .
RUN dotnet publish "backend.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 2: Runtime Image (Toi uu kich thuoc nhe & chay on dinh)
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 5000

ENTRYPOINT ["dotnet", "backend.dll"]
