Gitea (v1.25.2) — [修復 issue #35800](https://github.com/go-gitea/gitea/issues/35800)

說明
- 這個專案包含已修復 issue #35800 的 Gitea 可執行檔與來源（版本：v1.25.2）。
- 官方安裝文件：https://docs.gitea.com/category/installation

支援的安裝方式
以下提供三種常見的安裝方式與範例指令：從原始碼建置、使用 Docker、或直接使用二進位檔。

1) 從原始碼建置 (Installation from source)

- 先切換到來源目錄：

```
cd gitea-source
```

- 使用適當的 build 標籤建置（範例）:

```
TAGS="bindata sqlite sqlite_unlock_notify" make build
```

- 建置完成後可直接啟動 Web 服務：

```
./gitea web
```

2) 使用 Docker (Installation with Docker)

- 若有提供 `gitea.tar` 映像，可以先載入映像：

```
docker load --input gitea.tar
```

- 然後以容器執行（範例將 Web 對外綁定在主機的 8000）：

```
docker run -d -p 8000:3000 -p 2222:22 --name gitea gitea-35800
```

3) 使用二進位檔 (Installation from binary)

- 將二進位檔複製到系統 PATH 中

```
sudo cp gitea /usr/local/bin/gitea
```

- 其他步驟請參考官網
- 之後即可用 `gitea` 指令啟動或安裝為服務，詳情請參考官方文件。

其他說明
- 若要取得更多安裝或設定細節，請參閱官方文件： https://docs.gitea.com/category/installation
- 本專案主要為展示修補與測試用途；請在適當的測試環境中執行並依需求調整資料庫與設定。

