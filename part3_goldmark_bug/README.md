## Gitea (v1.25.2) — [修復 issue #35800](https://github.com/go-gitea/gitea/issues/35800)

### bug 解析

對於以單個或多個連字號行開頭的輸入，Goldmark 並沒有將文件解析為一個列表（List 節點），而是將其解析為一個頂層的文本塊（TextBlock）。這個文本塊包含了文字節點，其中包括字面上的星號和空格。根據測試，出現這種結果主要是因為 goldmark-meta 擴展將以連字號開頭的文本識別為 YAML Front Matter 的開頭。這導致整個區塊的解析失敗，並降級為普通的 TextBlock ，最終渲染出錯誤的結果。

為了避免讓 Goldmark 的 meta 擴展或解析器對這些行進行特殊處理，所以目前會對輸入進行預處理，以偵測不是有效 YAML Front Matter 的開頭連字號行（即 ExtractMetadataBytes 返回錯誤或元數據為空）。並在這些開頭的連字號行前面加上一個換行符 (\n)。這樣既能保留連字號，又不會改變解析行為，從而阻止其被誤判為 YAML Front Matter。

-----

### 說明
- 這個專案包含已修復 issue #35800 的 Gitea 可執行檔與來源（版本：v1.25.2）。
- 官方安裝文件：https://docs.gitea.com/category/installation

支援的安裝方式
以下提供三種常見的安裝方式與範例指令：從原始碼建置、使用 Docker、或直接使用二進位檔。

1) 從原始碼建置 (Installation from source)

- 先切換到來源目錄：

```
cd gitea
```

- 使用適當的 build 標籤建置（範例）:

```
TAGS="bindata sqlite sqlite_unlock_notify" make build
```

- 建置完成後可直接啟動 Web 服務：

```
./gitea web
```
- 系統需要安裝 go, node, make ，詳情請參考[官網](https://docs.gitea.com/installation/install-from-source)

2) 使用 Docker (Installation with Docker)

- 下載 [gitea.tar](https://drive.google.com/file/d/1mewM8wDPs0mBcHIb75wmPJZoicCNuQ-R/view?usp=drive_link) 映像，可以先載入映像：

```
docker load --input gitea.tar
```

- 然後以容器執行（範例將 Web 對外綁定在主機的 8000）：

```
docker run -d -p 8000:3000 -p 2222:22 --name gitea gitea-35800
```

3) 使用二進位檔 (Installation from binary)

- 下載 [gitea](https://drive.google.com/file/d/17HKr_c-pIA7s9AYUm7NqG27hxoOEIqKC/view?usp=sharing)
- 將二進位檔複製到系統 PATH 中

```
sudo cp gitea /usr/local/bin/gitea
```

- 其他步驟請參考[官網](https://docs.gitea.com/installation/install-from-binary)

其他說明
- 若要取得更多安裝或設定細節，請參閱官方文件： https://docs.gitea.com/category/installation
- 本專案主要為展示修補與測試用途；請在適當的測試環境中執行並依需求調整資料庫與設定。

