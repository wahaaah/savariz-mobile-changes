<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    echo json_encode(["success" => false, "message" => "No data received"]);
    exit;
}

$username = trim($data['username'] ?? '');
$password = $data['password'] ?? '';

if (!$username || !$password) {
    echo json_encode(["success" => false, "message" => "Username and password are required"]);
    exit;
}

$stmt = $conn->prepare("SELECT user_id, username, password_hash, full_name, role, is_active FROM users WHERE username = ? LIMIT 1");
$stmt->bind_param("s", $username);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();

if (!$user) {
    echo json_encode(["success" => false, "message" => "Invalid credentials"]);
    $stmt->close();
    $conn->close();
    exit;
}

if (!$user['is_active']) {
    echo json_encode(["success" => false, "message" => "Account is deactivated"]);
    $stmt->close();
    $conn->close();
    exit;
}

if (!password_verify($password, $user['password_hash'])) {
    echo json_encode(["success" => false, "message" => "Invalid credentials"]);
    $stmt->close();
    $conn->close();
    exit;
}

unset($user['password_hash']);

echo json_encode(["success" => true, "message" => "Login successful", "data" => $user]);

$stmt->close();
$conn->close();
?>