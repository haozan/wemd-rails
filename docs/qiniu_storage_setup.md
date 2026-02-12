# 七牛云存储配置指南

## 概述

本项目已配置使用七牛云对象存储来存储用户上传的图片文件。七牛云支持 S3 兼容 API，所以我们使用 `aws-sdk-s3` gem 来访问。

## 配置步骤

### 1. 注册七牛云账号并创建存储空间

1. 访问 [七牛云官网](https://www.qiniu.com/) 注册账号
2. 登录后进入 [对象存储控制台](https://portal.qiniu.com/kodo/bucket)
3. 创建一个新的存储空间（Bucket）
   - 选择合适的区域（推荐：华东-浙江）
   - 访问控制选择"公开"（用于图片访问）
   - 记录你的 Bucket 名称

### 2. 获取 AccessKey 和 SecretKey

1. 进入 [密钥管理](https://portal.qiniu.com/user/key)
2. 创建或查看你的 AccessKey 和 SecretKey
3. **重要：** 妥善保管 SecretKey，不要泄露

### 3. 配置环境变量

在 `config/application.yml` 文件中添加以下配置：

```yaml
# 七牛云存储配置
QINIU_ENDPOINT: 'https://s3-cn-east-1.qiniucs.com'  # 根据你的区域修改
QINIU_ACCESS_KEY: '你的AccessKey'
QINIU_SECRET_KEY: '你的SecretKey'
QINIU_REGION: 'cn-east-1'  # 根据你的区域修改
QINIU_BUCKET: '你的Bucket名称'
```

### 4. 区域对照表

| 七牛云区域 | Region 值 | Endpoint |
|-----------|-----------|----------|
| 华东-浙江 | cn-east-1 | https://s3-cn-east-1.qiniucs.com |
| 华北-河北 | cn-north-1 | https://s3-cn-north-1.qiniucs.com |
| 华南-广东 | cn-south-1 | https://s3-cn-south-1.qiniucs.com |
| 北美 | us-north-1 | https://s3-us-north-1.qiniucs.com |
| 东南亚 | ap-southeast-1 | https://s3-ap-southeast-1.qiniucs.com |

### 5. 生产环境配置

**方式 A：通过 Clacky 平台环境变量**

如果你在 Clacky 平台部署，在项目设置中添加环境变量：

```
QINIU_ENDPOINT=https://s3-cn-east-1.qiniucs.com
QINIU_ACCESS_KEY=你的AccessKey
QINIU_SECRET_KEY=你的SecretKey
QINIU_REGION=cn-east-1
QINIU_BUCKET=你的Bucket名称
```

**方式 B：通过系统环境变量**

```bash
export QINIU_ENDPOINT='https://s3-cn-east-1.qiniucs.com'
export QINIU_ACCESS_KEY='你的AccessKey'
export QINIU_SECRET_KEY='你的SecretKey'
export QINIU_REGION='cn-east-1'
export QINIU_BUCKET='你的Bucket名称'
```

### 6. 测试配置

启动 Rails 控制台测试上传：

```ruby
# 进入控制台
rails console

# 测试上传
blob = ActiveStorage::Blob.create_and_upload!(
  io: File.open('public/favicon.ico'),
  filename: 'test.ico',
  content_type: 'image/x-icon'
)

# 检查 URL
puts blob.url
# 应该返回类似：https://你的bucket.s3-cn-east-1.qiniucs.com/...
```

## 开发环境 vs 生产环境

### 开发环境（默认）
- 使用本地文件存储（`:local`）
- 文件存储在 `storage/` 目录
- 不需要配置七牛云

### 生产环境
- 使用七牛云存储（`:qiniu`）
- 文件上传到七牛云对象存储
- 需要配置上述环境变量

## 切换存储方式

如果需要在开发环境也使用七牛云，修改 `config/environments/development.rb`：

```ruby
# 改为使用七牛云
config.active_storage.service = :qiniu
```

## 常见问题

### Q: 上传失败，提示 "Access Denied"
**A:** 检查 AccessKey 和 SecretKey 是否正确，确保 Bucket 权限设置为"公开"。

### Q: 图片上传成功但无法访问
**A:** 检查：
1. Bucket 访问控制是否设置为"公开"
2. 域名配置是否正确（七牛云可以绑定自定义域名）
3. Endpoint 区域是否与 Bucket 所在区域一致

### Q: 如何绑定自定义域名？
**A:** 
1. 在七牛云控制台的 Bucket 设置中绑定域名
2. 添加 CNAME 记录到你的域名 DNS
3. 修改 `QINIU_ENDPOINT` 为你的自定义域名

### Q: 费用如何计算？
**A:** 七牛云按使用量计费：
- 存储费用：约 ¥0.148/GB/月
- 流量费用：约 ¥0.29/GB（CDN 加速）
- 每月有免费额度（10GB 存储 + 10GB 流量）

## 相关文件

- `config/storage.yml` - 存储配置
- `config/environments/production.rb` - 生产环境配置
- `config/application.yml` - 环境变量配置
- `app/services/qiniu_upload_service.rb` - 上传服务（使用 ActiveStorage）

## 技术细节

本项目使用 Rails ActiveStorage + AWS SDK S3 来访问七牛云：

1. **ActiveStorage** 提供统一的文件上传接口
2. **aws-sdk-s3** gem 提供 S3 协议支持
3. 七牛云兼容 S3 协议，所以可以直接使用 AWS SDK
4. `force_path_style: true` 配置确保路径格式兼容

## 迁移现有文件

如果你已经有本地文件需要迁移到七牛云：

```ruby
# 迁移脚本（在 Rails console 中执行）
ActiveStorage::Blob.find_each do |blob|
  if blob.service_name != 'qiniu'
    # 下载文件
    file = blob.download
    
    # 重新上传到七牛云
    new_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(file),
      filename: blob.filename.to_s,
      content_type: blob.content_type
    )
    
    # 更新所有引用
    blob.attachments.each do |attachment|
      attachment.update!(blob: new_blob)
    end
    
    # 删除旧 blob
    blob.purge
  end
end
```

## 备份建议

1. 定期备份数据库（包含文件元数据）
2. 七牛云控制台开启"版本控制"功能
3. 配置"生命周期规则"自动清理过期文件
