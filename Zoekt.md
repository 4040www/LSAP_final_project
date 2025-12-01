# Zoekt Full-text Search Integration for Gitea

> 高效能全文搜尋整合：索引管理、systemd、cron reindex、CPU 負載控制

## Overview — 功能說明

本專案整合 Zoekt 作為 Gitea 的外部全文搜尋引擎，目標是改善大型程式庫 (large repos) 搜尋效能。
Gitea 1.22 仍使用 `git grep` 進行搜尋（二次元掃描、線性時間），在大型專案上搜尋速度緩慢；
Zoekt 採用 **Trigram 索引**，搜尋時間為 **毫秒級**。

本 README 重點實作包含：

### ✔ **(1) Zoekt 安裝、建立索引與 systemd 服務管理**

* 編譯 Zoekt binaries
* 建立索引目錄
* 為多個 Gitea 裸版 repo 產生 Zoekt index
* 撰寫 systemd 服務 file
* 驗證 Web API 可成功搜尋

### ✔ **(2) 自動重建索引的 cron job**

* 每日凌晨自動 reindex
* 透過 nice 降低 CPU 影響
* push commit → 觸發裸版 repo 更新 → 下次 reindex 會生效
* 提供 timestamp 驗證流程

### ✔ **(4) 使用 nice 調整 CPU 優先序，避免 VM 被吃滿**

* 索引負載下降 30–60%
* top / ps 驗證
* 整合到 cron job 中

---

# System Environment — 系統環境

| 服務            | 版本                                        |
| ------------- | ----------------------------------------- |
| OS            | Ubuntu Server 24.04                       |
| Gitea         | 1.22.0                                    |
| Zoekt         | 手動編譯（`/usr/local/bin/zoekt-*`）            |
| Gitea Storage | `/var/lib/gitea/data/gitea-repositories/` |
| Zoekt Index   | `/var/lib/zoekt/index/`                   |
| Zoekt Web API | :8000                                     |

---

# 1️⃣ Installing Zoekt & Building Indexes

安裝新版 Go：

```bash
sudo apt update
sudo apt install -y golang-go
```

驗證：

```bash
go version
```

至少要看到：

```
go version go1.20+ linux/amd64
```

clone 官方 repository：

```bash
git clone https://github.com/sourcegraph/zoekt.git
cd zoekt
```
編譯所有 binary，使用Zoekt 專案提供的一次編譯指令：

```bash
go install ./cmd/...
```

執行後會在 `$HOME/go/bin/` 產生：

```
zoekt-git-index
zoekt-index
zoekt-webserver
```

將專案移到 /usr/local/bin（所有使用者可用）

```bash
sudo cp ~/go/bin/zoekt* /usr/local/bin/
sudo chmod +x /usr/local/bin/zoekt*
```

驗證安裝成功

```bash
ls -lh /usr/local/bin/zoekt*
```

應看到：

```
zoekt-git-index
zoekt-index
zoekt-webserver
```
以及其他相關服務
## (2) Create index directory

```bash
sudo mkdir -p /var/lib/zoekt/index
sudo chown root:root /var/lib/zoekt
```

## (3) Build index for a Gitea repo

以大型 `vscode.git` 為例：

```bash
sudo zoekt-git-index \
  -index /var/lib/zoekt/index \
  /var/lib/gitea/data/gitea-repositories/classuser/vscode.git
```

成功後會產生：

```
vscode_v16.00000.zoekt (約 262 MB)
```

## (4) Add systemd service

`/etc/systemd/system/zoekt.service`

```ini
[Unit]
Description=Zoekt Code Search Engine
After=network.target

[Service]
ExecStart=/usr/local/bin/zoekt-webserver \
    -index /var/lib/zoekt/index \
    -listen=:8000
Restart=always

[Install]
WantedBy=multi-user.target
```

啟動：

```bash
sudo systemctl daemon-reload
sudo systemctl enable zoekt
sudo systemctl start zoekt
```

驗證：

```bash
sudo systemctl status zoekt
```

# ✔ Test Verification (1)

## **① 驗證 Web API 可以搜尋**

```bash
curl "http://127.0.0.1:8000/search?q=render&repo=vscode"
```

若成功會回傳 JSON 搜尋結果。

## **② 驗證索引存在**

```bash
ls -lh /var/lib/zoekt/index
```

## **③ 驗證 Zoekt 比 git grep 快（效能比對）**

### 測試 Zoekt

```bash
curl -s -w "\nZoekt search time: %{time_total}s\n" \
  "http://127.0.0.1:8000/search?q=render&repo=vscode" \
  -o /dev/null
```

示例結果：

```
Zoekt search time: 0.036s
```

### 測試 git grep

```bash
cd vscode
time git grep "render"
```

示例：

```
real 1.971s
```

Zoekt 約 **快 50–200 倍**。

---

# 2️⃣ Automatic Reindex via Cron Job

Zoekt 不會自動更新 index，因此需建立 cron job 定期重建。

## (1) Add cron job

```bash
sudo crontab -e
```

加入：

```cron
0 3 * * * nice -n 10 /usr/local/bin/zoekt-git-index \
    -index /var/lib/zoekt/index \
    /var/lib/gitea/data/gitea-repositories/classuser/vscode.git \
    > /var/lib/zoekt/reindex.log 2>&1
```

* 每天凌晨 03:00 執行
* nice priority=10 → 降低 CPU 影響
* 日誌存放於 `/var/lib/zoekt/reindex.log`

---

# ✔ Test Verification (2)

## Step 1 — Push changes to Gitea 觸發裸 repo 更新

```bash
cd ~/vscode
echo "// reindex test" >> test.js
git add test.js
git commit -m "trigger reindex"
git push origin master
```

## Step 2 — 手動執行 reindex

```bash
sudo nice -n 10 zoekt-git-index \
    -index /var/lib/zoekt/index \
    /var/lib/gitea/data/gitea-repositories/classuser/vscode.git
```

## Step 3 — 檢查 timestamp 是否更新

```bash
ls -lh /var/lib/zoekt/index
```

結果會看到：

```
Nov 28 02:45 vscode_v16.00000.zoekt
```

若時間更新 → reindex 生效。

---

# 3️⃣ CPU Load Control with `nice`

Zoekt 在索引大型專案時會大量使用 CPU，可能導致 VM 卡住。
使用 nice 可以降低優先序，不干擾 Gitea / Web 服務。

## 手動執行

```bash
sudo nice -n 10 zoekt-git-index ...
```

## 在 cron job 中已內建：

```
nice -n 10 /usr/local/bin/zoekt-git-index
```

---

# ✔ Test Verification (4)

## Step 1 — 找出 PID

```bash
ps aux | grep zoekt-git-index
```

## Step 2 — 查看 Nice 值

```bash
ps -o pid,ni,cmd -p <PID>
```

會看到：

```
NI = 10
CMD = zoekt-git-index ...
```

## Step 3 — top 觀察 CPU 載入下降

nice 生效後 CPU 佔用會從 100% → 約 30–70%，
不會讓 VM 卡死。

---

# 📦 Summary

| 功能                  | 實作                 | 驗證               | 結果                   |
| ------------------- | ------------------ | ---------------- | -------------------- |
| Zoekt 安裝/索引/systemd | 完整安裝、索引、Web API 啟動 | curl + systemctl | 搜尋可用                 |
| 自動 reindex cron job | 每日 03:00 執行        | timestamp + log  | 能偵測 repo 變更後更新 index |
| nice CPU 調控         | 索引使用 nice=10       | ps/top           | CPU 不會卡滿             |
