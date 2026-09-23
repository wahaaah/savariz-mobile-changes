<?php

$host = getenv('MYSQLHOST') ?: getenv('DB_HOST') ?: 'iriguchi.proxy.rlwy.net';
$db = getenv('MYSQL_DATABASE') ?: getenv('DB_NAME') ?: 'railway';
$user = getenv('MYSQLUSER') ?: getenv('DB_USER') ?: 'root';
$pass = getenv('MYSQLPASSWORD') ?: getenv('DB_PASSWORD') ?: getenv('DB_PASS') ?: 'JPKfxDmFHQaVNkMtBySKwpskXNpyeFBx';
$port = (int) (getenv('MYSQLPORT') ?: getenv('DB_PORT') ?: 21536);

$conn = @new mysqli($host, $user, $pass, $db, $port);

if ($conn->connect_error) {
    $conn = null;
}

if ($conn === null || $conn->connect_error) {
    http_response_code(500);
    die(json_encode([
        'success' => false,
        'message' => 'Database connection failed. Check XAMPP MySQL is running and the credentials match.'
    ]));
}

if ($conn === null || $conn->connect_error) {
    http_response_code(500);
    die(json_encode([
        'success' => false,
        'message' => 'Database connection failed. Check XAMPP MySQL is running and the credentials match.'
    ]));
}

$conn->set_charset('utf8mb4');

function ensure_patient_table($conn) {
    $conn->query("CREATE TABLE IF NOT EXISTS patients (
        patient_id VARCHAR(50) NOT NULL PRIMARY KEY,
        first_name VARCHAR(50) DEFAULT NULL,
        last_name VARCHAR(50) DEFAULT NULL,
        email VARCHAR(100) DEFAULT NULL,
        password VARCHAR(255) DEFAULT NULL,
        name VARCHAR(255) DEFAULT NULL,
        age INT DEFAULT NULL,
        gender VARCHAR(30) DEFAULT 'Male',
        contact VARCHAR(50) DEFAULT NULL,
        last_visit TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        status VARCHAR(50) DEFAULT 'Active',
        created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        date_of_birth DATE DEFAULT NULL
    ) ENGINE=InnoDB");

    $columns = $conn->query("SHOW COLUMNS FROM patients");
    $existing = [];
    while ($column = $columns->fetch_assoc()) {
        $existing[] = $column['Field'];
    }

    foreach (['age2', 'gender2', 'contact_number'] as $legacyField) {
        if (in_array($legacyField, $existing, true)) {
            $conn->query("ALTER TABLE patients DROP COLUMN $legacyField");
        }
    }

    $additions = [
        ['first_name', 'VARCHAR(50) NULL DEFAULT NULL'],
        ['last_name', 'VARCHAR(50) NULL DEFAULT NULL'],
        ['email', 'VARCHAR(100) NULL DEFAULT NULL'],
        ['password', 'VARCHAR(255) NULL DEFAULT NULL'],
        ['name', 'VARCHAR(255) NULL DEFAULT NULL'],
        ['age', 'INT NULL DEFAULT NULL'],
        ['gender', 'VARCHAR(30) NULL DEFAULT "Male"'],
        ['date_of_birth', 'DATE NULL DEFAULT NULL'],
        ['contact', 'VARCHAR(50) NULL DEFAULT NULL'],
        ['last_visit', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP'],
        ['status', 'VARCHAR(50) NULL DEFAULT "Active"'],
        ['created_at', 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP'],
    ];

    foreach ($additions as [$field, $definition]) {
        if (!in_array($field, $existing, true)) {
            $conn->query("ALTER TABLE patients ADD COLUMN $field $definition");
        }
    }

    $conn->query("UPDATE patients p
        LEFT JOIN patient_auth pa ON pa.patient_id = p.patient_id
        SET p.first_name = COALESCE(NULLIF(TRIM(p.first_name), ''), SUBSTRING_INDEX(TRIM(p.name), ' ', 1)),
            p.last_name = COALESCE(NULLIF(TRIM(p.last_name), ''), TRIM(SUBSTRING(TRIM(p.name), LOCATE(' ', TRIM(p.name)) + 1))),
            p.email = COALESCE(NULLIF(TRIM(p.email), ''), pa.email),
            p.password = COALESCE(NULLIF(TRIM(p.password), ''), pa.password_hash),
            p.name = COALESCE(NULLIF(TRIM(p.name), ''), CONCAT_WS(' ', p.first_name, p.last_name))
        WHERE p.patient_id IS NOT NULL");

    $conn->query("UPDATE patients
        SET age = COALESCE(age, CASE WHEN date_of_birth IS NOT NULL THEN TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) ELSE 0 END),
            gender = COALESCE(NULLIF(TRIM(gender), ''), 'Male')
        WHERE age IS NULL OR gender IS NULL OR TRIM(gender) = ''");
}

function ensure_patient_auth_table($conn) {
    $conn->query("CREATE TABLE IF NOT EXISTS patient_auth (
        patient_auth_id INT AUTO_INCREMENT PRIMARY KEY,
        patient_id VARCHAR(50) NOT NULL UNIQUE,
        email VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB");
}

function ensure_frames_table($conn) {
    $conn->query("CREATE TABLE IF NOT EXISTS frames (
        frame_id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(150) NOT NULL,
        brand VARCHAR(100) DEFAULT NULL,
        material VARCHAR(100) DEFAULT NULL,
        category VARCHAR(50) DEFAULT NULL,
        description TEXT DEFAULT NULL,
        price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        stock_quantity INT NOT NULL DEFAULT 0,
        image_2d_url VARCHAR(255) DEFAULT NULL,
        image_url VARCHAR(255) DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB");

    $columns = $conn->query("SHOW COLUMNS FROM frames");
    $existing = [];
    while ($column = $columns->fetch_assoc()) {
        $existing[] = $column['Field'];
    }

    foreach (['brand', 'material', 'category', 'description', 'price', 'stock_quantity', 'image_2d_url', 'image_url'] as $field) {
        if (!in_array($field, $existing, true)) {
            $additions = [
                'brand' => 'VARCHAR(100) NULL DEFAULT NULL',
                'material' => 'VARCHAR(100) NULL DEFAULT NULL',
                'category' => 'VARCHAR(50) NULL DEFAULT NULL',
                'description' => 'TEXT NULL DEFAULT NULL',
                'price' => 'DECIMAL(10,2) NOT NULL DEFAULT 0.00',
                'stock_quantity' => 'INT NOT NULL DEFAULT 0',
                'image_2d_url' => 'VARCHAR(255) NULL DEFAULT NULL',
                'image_url' => 'VARCHAR(255) NULL DEFAULT NULL',
            ];
            if (isset($additions[$field])) {
                $conn->query("ALTER TABLE frames ADD COLUMN $field {$additions[$field]}");
            }
        }
    }
}

function normalize_gender($gender) {
    $normalized = trim((string) $gender);
    if ($normalized === '') {
        return 'Male';
    }

    $lower = strtolower($normalized);
    if ($lower === 'male' || $lower === 'm') {
        return 'Male';
    }
    if ($lower === 'female' || $lower === 'f') {
        return 'Female';
    }

    return 'Male';
}

function calculate_age_from_birth_date($dateOfBirth) {
    $birth = trim((string) $dateOfBirth);
    if ($birth === '') {
        return null;
    }

    $date = DateTime::createFromFormat('Y-m-d', $birth) ?: new DateTime($birth);
    if ($date === false) {
        return null;
    }

    $today = new DateTime('today');
    $age = $today->diff($date)->y;
    return $age < 0 ? null : $age;
}

function split_name($fullName) {
    $trimmed = trim((string) $fullName);
    if ($trimmed === '') {
        return ['first_name' => '', 'last_name' => ''];
    }

    $parts = preg_split('/\s+/', $trimmed);
    if (count($parts) <= 1) {
        return ['first_name' => $trimmed, 'last_name' => ''];
    }

    return [
        'first_name' => $parts[0],
        'last_name' => implode(' ', array_slice($parts, 1)),
    ];
}

function parse_appointment_purpose($provider, $appointmentType) {
    $providerName = trim((string) $provider);
    $typeName = trim((string) $appointmentType);

    if ($providerName !== '' && $typeName !== '') {
        return $providerName . ' - ' . $typeName;
    }

    return $providerName !== '' ? $providerName : $typeName;
}

function normalize_appointment_record($row) {
    $purpose = trim((string) ($row['purpose_of_visit'] ?? ''));
    $provider = '';
    $appointmentType = '';

    if ($purpose !== '') {
        $parts = explode(' - ', $purpose, 2);
        $provider = trim($parts[0]);
        if (count($parts) > 1) {
            $appointmentType = trim($parts[1]);
        }
    }

    if ($provider === '' && isset($row['provider'])) {
        $provider = trim((string) $row['provider']);
    }
    if ($appointmentType === '' && isset($row['appointment_type'])) {
        $appointmentType = trim((string) $row['appointment_type']);
    }

    $status = trim((string) ($row['appointment_status'] ?? $row['status'] ?? 'Pending'));
    if ($status === '') {
        $status = 'Pending';
    }

    return [
        'appointment_id' => $row['appointment_id'] ?? null,
        'patient_id' => $row['patient_id'] ?? null,
        'appointment_date' => $row['appointment_date'] ?? null,
        'appointment_time' => $row['appointment_time'] ?? null,
        'provider' => $provider,
        'appointment_type' => $appointmentType,
        'status' => $status,
        'appointment_status' => $status,
        'created_at' => $row['created_at'] ?? null,
    ];
}

function normalize_image_url($rawUrl) {
    if ($rawUrl === null || trim((string) $rawUrl) === '') {
        return null;
    }

    $url = trim((string) $rawUrl);
    $normalized = preg_replace('#https?://(localhost|127\.0\.0\.1|192\.168\.100\.23)(?::5000)?#', 'http://10.0.2.2:5000', $url);
    if ($normalized !== null && $normalized !== $url) {
        return $normalized;
    }

    if (preg_match('#^/uploads/#', $url) || preg_match('#^uploads/#', $url)) {
        return 'http://10.0.2.2:5000/' . ltrim($url, '/');
    }

    if (preg_match('#^https?://#', $url)) {
        return $url;
    }

    return 'http://10.0.2.2:5000/' . ltrim($url, '/');
}

function normalize_frame_record($row) {
    $imageUrl = normalize_image_url($row['image_2d_url'] ?? $row['image_url'] ?? null);

    return [
        'frame_id' => $row['frame_id'] ?? null,
        'name' => $row['name'] ?? $row['frame_name'] ?? '',
        'frame_name' => $row['name'] ?? $row['frame_name'] ?? '',
        'brand' => $row['brand'] ?? null,
        'material' => $row['material'] ?? null,
        'category' => $row['category'] ?? '',
        'description' => $row['description'] ?? '',
        'price' => $row['price'] ?? 0,
        'stock_quantity' => $row['stock_quantity'] ?? $row['stock'] ?? 0,
        'stock' => $row['stock_quantity'] ?? $row['stock'] ?? 0,
        'image_2d_url' => $imageUrl,
        'image_url' => $imageUrl,
    ];
}
?>