# API 项目说明

这是一个 PHP + MongoDB + Shell 脚本集成的 API 项目。

## 目录结构

```
api/
├── index.php           # 主 API 文件
├── scripts/            # Shell 脚本目录
│   ├── backup.sh      # MongoDB 备份脚本
│   ├── cleanup.sh     # 清理脚本
│   └── test.sh        # 测试脚本
└── data/               # JSON 数据文件
    ├── users.json     # 用户数据示例
    └── products.json  # 产品数据示例
```

## API 接口

### 1. 获取 API 信息
```bash
GET /
GET /api
```

### 2. 健康检查
```bash
GET /api/health
```

### 3. 执行 Shell 脚本
```bash
POST /api/exec-script
Content-Type: application/json

{
  "script": "test.sh",
  "args": ["arg1", "arg2"]
}
```

### 4. 清空 MongoDB 集合
```bash
POST /api/mongo/clear
Content-Type: application/json

{
  "collection": "users"
}
```

### 5. 导入 JSON 到 MongoDB
```bash
# 从文件导入
POST /api/mongo/import
Content-Type: application/json

{
  "collection": "users",
  "file": "users.json"
}

# 直接传数据
POST /api/mongo/import
Content-Type: application/json

{
  "collection": "users",
  "data": [
    {"name": "测试", "age": 20}
  ]
}
```

### 6. 导出 MongoDB 数据
```bash
GET /api/mongo/export?collection=users&limit=100
```

### 7. 查询 MongoDB 数据
```bash
GET /api/mongo/query?collection=users&limit=10
GET /api/mongo/query?collection=users&filter={"age":25}&limit=10
```

## 安全说明

1. Shell 脚本使用白名单机制，只能执行指定的脚本
2. 文件路径使用 basename() 防止路径遍历攻击
3. 建议在生产环境中添加认证机制
