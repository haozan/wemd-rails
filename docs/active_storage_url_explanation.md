# ActiveStorage 图片 URL 说明

## 问题：为什么图片链接还是显示 clackypaas 域名？

你可能遇到这个疑惑：明明配置了七牛云存储，为什么上传的图片 URL 还是显示应用的域名，而不是七牛云的域名？

**答案：这是 ActiveStorage 的设计机制，文件确实已经存储在七牛云了！**

## ActiveStorage 的工作原理

### 方式一：代理访问（Rails 默认方式）

```
用户浏览器 → Rails 应用 → 七牛云存储
```

**URL 格式：**
```
https://yourapp.com/rails/active_storage/blobs/redirect/xxx/filename.jpg
```

**工作流程：**
1. 用户上传图片 → Rails 收到文件 → **直接上传到七牛云**
2. 数据库记录：文件存储在 `service_name: qiniu`
3. 用户访问图片 → Rails 生成代理 URL → 用户点击后 Rails 从七牛云获取文件 → 返回给用户

**优点：**
✅ 文件真实存储在七牛云（可以在七牛云控制台看到）
✅ 更好的访问控制（可以检查权限）
✅ 统一的 URL 格式
✅ 可以随时更换存储服务而不改变 URL

**缺点：**
❌ 图片流量经过应用服务器
❌ 增加服务器负载

### 方式二：直接访问（Public URL）

```
用户浏览器 → 七牛云存储
```

**URL 格式：**
```
https://s3-cn-south-1.qiniucs.com/atompic/xxxkey
```

**配置方法：**
```yaml
# config/application.yml
QINIU_PUBLIC: 'true'
```

**要求：**
1. 七牛云 Bucket 必须设置为「公开空间」
2. 所有文件可被公开访问

**优点：**
✅ 流量不经过应用服务器
✅ 减少服务器负载

**缺点：**
❌ URL 是 S3 endpoint，不是 CDN 域名，速度可能慢
❌ 无法使用七牛云自定义域名（S3 API 限制）
❌ 失去访问控制能力
❌ 所有文件必须公开

## 如何验证文件确实在七牛云？

### 方法一：检查数据库

```bash
rails runner "blob = ActiveStorage::Blob.last; puts blob.service_name"
# 输出: qiniu  ← 说明存储在七牛云
```

### 方法二：查看七牛云控制台

1. 访问：https://portal.qiniu.com/kodo/bucket/resource?bucketName=atompic
2. 可以看到上传的所有文件
3. 文件名（Key）格式如：`pwguo7hx9oufpm1vefynbuvzr7kb`

### 方法三：检查本地存储目录

```bash
ls storage/
# 如果文件在七牛云，storage/ 目录不会有新文件生成
```

## 推荐方案

### 大多数情况：使用默认的代理方式

保持 `QINIU_PUBLIC: 'false'`（默认值），理由：

1. ✅ **文件确实存储在七牛云**，不占用本地空间
2. ✅ 容器重启不会丢失文件
3. ✅ 更好的安全性和访问控制
4. ✅ URL 格式统一，便于管理
5. ✅ 可以在后台轻松切换存储服务

### 特殊情况：需要 CDN 加速

如果你的应用有大量图片访问，需要 CDN 加速：

#### 选项 A：使用反向代理 CDN
在你的域名前加 CDN（如 CloudFlare、阿里云 CDN）：
```
用户 → CDN → Rails 应用 → 七牛云
```
这样 Rails 代理的 URL 也会被 CDN 缓存。

#### 选项 B：改用七牛云原生 SDK
不使用 S3 兼容 API，改用七牛云官方 Ruby SDK：
- 可以直接生成七牛云 CDN 域名的 URL
- 需要修改代码，替换 ActiveStorage 的 URL 生成逻辑
- 需要在七牛云绑定自定义域名（需备案）

## 常见误解

### ❌ 误解："URL 显示我的域名，说明文件还在本地"
✅ 正确：URL 只是访问入口，文件实际存储位置由 `service_name` 决定

### ❌ 误解："必须使用七牛云域名才算成功"
✅ 正确：Rails 代理方式也是成功的，文件确实在七牛云

### ❌ 误解："代理方式会很慢"
✅ 正确：Rails 只是转发请求，文件直接从七牛云传输给用户

## 总结

**你的配置已经成功了！**

- 文件存储：✅ 七牛云（华南区域）
- 容器重启：✅ 文件不会丢失
- URL 显示：应用域名（这是正常的）
- 实际存储：七牛云（可在控制台验证）

**是否需要改成直接 URL？**
- 大多数情况：不需要
- 如果有大量图片访问：考虑在应用前加 CDN
- 如果必须要七牛云 CDN 域名：需要改用七牛云原生 SDK（工作量较大）
