# 主题同步功能

## 功能说明

在生产环境部署后，可以使用后台的"Sync Themes"按钮一键同步所有内置主题。

## 使用方法

1. 登录管理员后台 `/admin/login`
2. 在 Dashboard 页面找到 **Quick Actions** 区域
3. 点击紫色的 **Sync Themes** 按钮
4. 确认同步操作
5. 系统会从主题文件重新读取并更新所有13个内置主题

## 技术实现

### 文件结构

- **控制器**: `app/controllers/admin/themes_controller.rb`
- **路由**: `POST /admin/themes/sync`
- **前端控制器**: `app/javascript/controllers/theme_sync_controller.ts`
- **视图**: `app/views/admin/dashboard/index.html.erb`
- **测试**: `spec/requests/admin/themes_sync_spec.rb`

### 同步逻辑

1. 读取 `app/assets/themes/` 目录下的主题CSS文件
2. 每个主题由3个文件组成：`basic.css` + 主题特定CSS + `code-github.css`
3. 合并文件内容并更新数据库中的内置主题
4. 用户自定义主题（`is_builtin: false`）不受影响

### 内置主题列表（13个）

1. 默认主题
2. 学术论文
3. 极光玻璃
4. 包豪斯
5. 赛博朋克
6. 知识库
7. **李笑来原版** (新增)
8. 黑金奢华
9. 莫兰迪森林
10. 新粗野主义
11. 购物小票
12. 落日胶片
13. 主题模板

## 注意事项

- 同步操作会覆盖所有内置主题的CSS
- 确保 `app/assets/themes/` 目录下的文件是最新版本
- 用户自定义主题不会被同步功能影响
- 建议在非高峰期执行同步操作

## 测试

运行测试确保功能正常：

```bash
bundle exec rspec spec/requests/admin/themes_sync_spec.rb
```

所有测试应该通过，验证：
- 同步创建/更新13个内置主题
- 主题CSS正确更新
- 用户自定义主题未受影响
