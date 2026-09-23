<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    echo json_encode([
        "success" => false,
        "message" => "No data received"
    ]);
    exit;
}

$patient_id = $data['patient_id'] ?? null;
$current_password = $data['current_password'] ?? '';
$new_password = $data['new_password'] ?? '';

if (!$patient_id || !$current_password || !$new_password) {
    echo json_encode([
        "success" => false,
        "message" => "All fields are required"
    ]);
    exit;
}

$stmt = $conn->prepare("SELECT password_hash FROM patient_auth WHERE patient_id = ?");
$stmt->bind_param("s", $patient_id);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();

if (!$user) {
    echo json_encode([
        "success" => false,
        "message" => "Patient not found"
    ]);
    $stmt->close();
    $conn->close();
    exit;
}

if (!password_verify($current_password, $user['password_hash'])) {
    echo json_encode([
        "success" => false,
        "message" => "Current password is incorrect"
    ]);
    $stmt->close();
    $conn->close();
    exit;
}

$new_password_hash = password_hash($new_password, PASSWORD_DEFAULT);

$stmt = $conn->prepare("UPDATE patient_auth SET password_hash = ? WHERE patient_id = ?");
$stmt->bind_param("ss", $new_password_hash, $patient_id);

if ($stmt->execute()) {
    echo json_encode([
        "success" => true,
        "message" => "Password changed successfully"
    ]);
} else {
    echo json_encode([
        "success" => false,
        "message" => $stmt->error
    ]);
}

$stmt->close();
$conn->close();
?>