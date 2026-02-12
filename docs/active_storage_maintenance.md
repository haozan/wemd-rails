# Active Storage 维护指南

## 问题说明

当你上传图片后过一段时间无法访问，通常是因为以下原因之一：

### 1. 数据库重置导致的孤立文件

**症状：**
- `storage/` 目录下有文件，但访问时返回 404
- 数据库中 `active_storage_attachments` 和 `active_storage_blobs` 表为空

**原因：**
执行了 `rails db:reset`、`rails db:drop` 或手动删除数据库时，数据库记录被清空，但 `storage/` 目录下的文件没有被删除。

**解决方案：**
```bash
# 清理孤立文件
rm -rf storage/*
touch storage/.keep

# 如果需要保留数据，在重置数据库前先备份
rails db:backup  # 如果有备份任务
```

### 2. 生产环境部署问题

**症状：**
- 本地开发环境正常，生产环境无法访问图片

**原因：**
- 使用 `:local` 存储时，每次部署都会创建新的容器，之前上传的文件会丢失
- `.gitignore` 已正确配置不提交 `storage/` 目录

**解决方案：**

#### 方案 A：使用云存储（推荐生产环境）

编辑 `config/environments/production.rb`：
```ruby
# 改为使用 S3 或其他云存储
config.active_storage.service = :storage_bucket
```

确保 `config/storage.yml` 已配置：
```yaml
storage_bucket:
  service: S3
  endpoint: <%= ENV.fetch("STORAGE_BUCKET_ENDPOINT", "") %>
  access_key_id: <%= ENV.fetch("STORAGE_BUCKET_ACCESS_KEY_ID", "") %>
  secret_access_key: <%= ENV.fetch("STORAGE_BUCKET_SECRET_ACCESS_KEY", "") %>
  region: <%= ENV.fetch("STORAGE_BUCKET_REGION", "") %>
  bucket: <%= ENV.fetch("STORAGE_BUCKET_NAME", "") %>
```

在 `config/application.yml` 中添加环境变量：
```yaml
STORAGE_BUCKET_ENDPOINT: "https://s3.amazonaws.com"
STORAGE_BUCKET_ACCESS_KEY_ID: "your-access-key"
STORAGE_BUCKET_SECRET_ACCESS_KEY: "your-secret-key"
STORAGE_BUCKET_REGION: "us-east-1"
STORAGE_BUCKET_NAME: "your-bucket-name"
```

#### 方案 B：使用持久化卷（仅容器化部署）

如果必须使用本地存储，需要配置持久化卷：

**Docker Compose:**
```yaml
services:
  web:
    volumes:
      - ./storage:/rails/storage
```

**Kubernetes:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: storage-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      volumes:
        - name: storage
          persistentVolumeClaim:
            claimName: storage-pvc
      containers:
        - name: web
          volumeMounts:
            - name: storage
              mountPath: /rails/storage
```

### 3. 检查当前状态

```bash
# 检查数据库记录
rails runner "puts 'Attachments: ' + ActiveStorage::Attachment.count.to_s; puts 'Blobs: ' + ActiveStorage::Blob.count.to_s"

# 检查文件系统
find storage/ -type f | wc -l

# 清理孤立文件（没有数据库记录的文件）
rails runner "
  file_keys = Dir.glob('storage/**/*').select { |f| File.file?(f) }.map { |f| f.split('/').last(2).join('/') }
  db_keys = ActiveStorage::Blob.pluck(:key)
  orphaned = file_keys - db_keys
  orphaned.each { |key| puts 'Orphaned: ' + key }
"
```

### 4. 预防措施

**开发环境：**
```bash
# 如果需要重置数据库，同时清理文件
rails db:reset && rm -rf storage/* && touch storage/.keep
```

**生产环境：**
- ✅ 使用云存储服务（S3、阿里云 OSS 等）
- ✅ 配置持久化卷
- ❌ 不要使用本地文件存储

**Git 配置（已正确配置）：**
```gitignore
/storage/*
!/storage/.keep
```

## 当前项目配置

- **开发环境：** `:local` （存储在 `storage/` 目录）
- **生产环境：** `:local` （存储在 `storage/` 目录）
- **云存储配置：** 已配置 `:storage_bucket`（S3 兼容）

## 建议

如果你的应用需要上传图片功能：

1. **开发环境**可以继续使用 `:local`
2. **生产环境**应该切换到 `:storage_bucket` 并配置云存储
3. 配置环境变量后，修改 `config/environments/production.rb` 第 34 行
