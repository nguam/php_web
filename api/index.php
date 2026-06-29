<?php
// 设置响应头为 JSON
header('Content-Type: application/json; charset=utf-8');

// 允许跨域（根据需要调整）
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type');

// 错误处理（生产环境建议关闭详细错误）
ini_set('display_errors', 1);
error_reporting(E_ALL);

// MongoDB 连接配置
define('MONGO_HOST', 'localhost');
define('MONGO_PORT', 27017);
define('MONGO_DB', 'mydb');

// 脚本目录
define('SCRIPT_DIR', __DIR__ . '/scripts');
define('DATA_DIR', __DIR__ . '/data');

// 简单路由
$method = $_SERVER['REQUEST_METHOD'];
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

try {
    switch ($path) {
        case '/':
        case '/api':
            apiInfo();
            break;

        case '/api/exec-script':
            if ($method === 'POST') {
                execScript();
            } else {
                error405();
            }
            break;

        case '/api/mongo/clear':
            if ($method === 'POST') {
                clearMongoDB();
            } else {
                error405();
            }
            break;

        case '/api/mongo/import':
            if ($method === 'POST') {
                importJSON();
            } else {
                error405();
            }
            break;

        case '/api/mongo/export':
            if ($method === 'GET') {
                exportJSON();
            } else {
                error405();
            }
            break;

        case '/api/mongo/query':
            if ($method === 'GET') {
                queryMongoDB();
            } else {
                error405();
            }
            break;

        case '/api/health':
            healthCheck();
            break;

        default:
            error404();
    }
} catch (Exception $e) {
    response(['error' => $e->getMessage()], 500);
}

// ========== 功能函数 ==========

/**
 * API 信息
 */
function apiInfo() {
    response([
        'name' => 'MongoDB & Shell API',
        'version' => '1.0.0',
        'endpoints' => [
            'GET /' => 'API 信息',
            'GET /api/health' => '健康检查',
            'POST /api/exec-script' => '执行 Shell 脚本',
            'POST /api/mongo/clear' => '清空 MongoDB 集合',
            'POST /api/mongo/import' => '导入 JSON 到 MongoDB',
            'GET /api/mongo/export' => '导出 MongoDB 数据',
            'GET /api/mongo/query' => '查询 MongoDB 数据'
        ]
    ]);
}

/**
 * 健康检查
 */
function healthCheck() {
    $status = [
        'status' => 'ok',
        'timestamp' => date('Y-m-d H:i:s'),
        'php_version' => PHP_VERSION,
        'services' => []
    ];

    // 检查 MongoDB
    try {
        $mongo = new MongoDB\Driver\Manager("mongodb://" . MONGO_HOST . ":" . MONGO_PORT);
        $command = new MongoDB\Driver\Command(['ping' => 1]);
        $mongo->executeCommand('admin', $command);
        $status['services']['mongodb'] = 'connected';
    } catch (Exception $e) {
        $status['services']['mongodb'] = 'disconnected';
        $status['status'] = 'degraded';
    }

    // 检查 Redis
    try {
        $redis = new Redis();
        $redis->connect('127.0.0.1', 6379);
        $redis->ping();
        $redis->close();
        $status['services']['redis'] = 'connected';
    } catch (Exception $e) {
        $status['services']['redis'] = 'disconnected';
        $status['status'] = 'degraded';
    }

    response($status);
}

/**
 * 执行 Shell 脚本
 */
function execScript() {
    $input = json_decode(file_get_contents('php://input'), true);
    $scriptName = $input['script'] ?? '';
    $args = $input['args'] ?? [];

    // 安全检查：白名单机制
    $allowedScripts = ['backup.sh', 'import.sh', 'cleanup.sh', 'test.sh'];
    if (!in_array($scriptName, $allowedScripts)) {
        response(['error' => '不允许执行此脚本', 'allowed' => $allowedScripts], 403);
    }

    $scriptPath = SCRIPT_DIR . '/' . $scriptName;
    if (!file_exists($scriptPath)) {
        response(['error' => '脚本不存在'], 404);
    }

    // 构建命令（安全地传递参数）
    $command = "bash " . escapeshellarg($scriptPath);
    if (!empty($args)) {
        foreach ($args as $arg) {
            $command .= " " . escapeshellarg($arg);
        }
    }

    // 执行脚本
    $output = [];
    $returnVar = 0;
    exec($command . " 2>&1", $output, $returnVar);

    response([
        'success' => $returnVar === 0,
        'script' => $scriptName,
        'output' => implode("\n", $output),
        'exit_code' => $returnVar
    ]);
}

/**
 * 清空 MongoDB 集合
 */
function clearMongoDB() {
    $input = json_decode(file_get_contents('php://input'), true);
    $collection = $input['collection'] ?? '';

    if (empty($collection)) {
        response(['error' => '请指定集合名称'], 400);
    }

    try {
        $mongo = new MongoDB\Driver\Manager("mongodb://" . MONGO_HOST . ":" . MONGO_PORT);
        $bulk = new MongoDB\Driver\BulkWrite;
        $bulk->delete([], ['limit' => 0]);  // 删除所有文档

        $result = $mongo->executeBulkWrite(MONGO_DB . '.' . $collection, $bulk);

        response([
            'success' => true,
            'collection' => $collection,
            'deleted_count' => $result->getDeletedCount()
        ]);
    } catch (Exception $e) {
        response(['error' => 'MongoDB 操作失败: ' . $e->getMessage()], 500);
    }
}

/**
 * 导入 JSON 数据到 MongoDB
 */
function importJSON() {
    $input = json_decode(file_get_contents('php://input'), true);
    $collection = $input['collection'] ?? '';
    $jsonFile = $input['file'] ?? '';  // 文件名或直接传 data 数组

    if (empty($collection)) {
        response(['error' => '请指定集合名称'], 400);
    }

    try {
        $mongo = new MongoDB\Driver\Manager("mongodb://" . MONGO_HOST . ":" . MONGO_PORT);
        $bulk = new MongoDB\Driver\BulkWrite;

        // 方式1：从文件读取
        if (!empty($jsonFile)) {
            $filePath = DATA_DIR . '/' . basename($jsonFile);  // 防止路径遍历
            if (!file_exists($filePath)) {
                response(['error' => 'JSON 文件不存在'], 404);
            }
            $jsonContent = file_get_contents($filePath);
            $data = json_decode($jsonContent, true);
        }
        // 方式2：直接从请求体接收数据
        else if (isset($input['data'])) {
            $data = $input['data'];
        } else {
            response(['error' => '请提供 file 或 data 参数'], 400);
        }

        if (!is_array($data)) {
            response(['error' => 'JSON 格式错误'], 400);
        }

        // 批量插入
        $count = 0;
        foreach ($data as $document) {
            $bulk->insert($document);
            $count++;
        }

        $result = $mongo->executeBulkWrite(MONGO_DB . '.' . $collection, $bulk);

        response([
            'success' => true,
            'collection' => $collection,
            'inserted_count' => $result->getInsertedCount(),
            'total_documents' => $count
        ]);
    } catch (Exception $e) {
        response(['error' => 'MongoDB 导入失败: ' . $e->getMessage()], 500);
    }
}

/**
 * 导出 MongoDB 数据为 JSON
 */
function exportJSON() {
    $collection = $_GET['collection'] ?? '';
    $limit = (int)($_GET['limit'] ?? 100);

    if (empty($collection)) {
        response(['error' => '请指定集合名称'], 400);
    }

    try {
        $mongo = new MongoDB\Driver\Manager("mongodb://" . MONGO_HOST . ":" . MONGO_PORT);
        $query = new MongoDB\Driver\Query([], ['limit' => $limit]);
        $cursor = $mongo->executeQuery(MONGO_DB . '.' . $collection, $query);

        $documents = [];
        foreach ($cursor as $document) {
            $documents[] = $document;
        }

        response([
            'success' => true,
            'collection' => $collection,
            'count' => count($documents),
            'data' => $documents
        ]);
    } catch (Exception $e) {
        response(['error' => 'MongoDB 查询失败: ' . $e->getMessage()], 500);
    }
}

/**
 * 查询 MongoDB 数据
 */
function queryMongoDB() {
    $collection = $_GET['collection'] ?? '';
    $filter = json_decode($_GET['filter'] ?? '{}', true);
    $limit = (int)($_GET['limit'] ?? 10);

    if (empty($collection)) {
        response(['error' => '请指定集合名称'], 400);
    }

    try {
        $mongo = new MongoDB\Driver\Manager("mongodb://" . MONGO_HOST . ":" . MONGO_PORT);
        $query = new MongoDB\Driver\Query($filter, ['limit' => $limit]);
        $cursor = $mongo->executeQuery(MONGO_DB . '.' . $collection, $query);

        $documents = [];
        foreach ($cursor as $document) {
            $documents[] = $document;
        }

        response([
            'success' => true,
            'collection' => $collection,
            'count' => count($documents),
            'data' => $documents
        ]);
    } catch (Exception $e) {
        response(['error' => 'MongoDB 查询失败: ' . $e->getMessage()], 500);
    }
}

// ========== 辅助函数 ==========

function response($data, $code = 200) {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}

function error404() {
    response(['error' => '接口不存在'], 404);
}

function error405() {
    response(['error' => '方法不允许'], 405);
}
?>
