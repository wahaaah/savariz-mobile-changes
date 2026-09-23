<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    echo json_encode(["success" => false, "message" => "No data received"]);
    exit;
}

ensure_patient_table($conn);
ensure_patient_auth_table($conn);

// Safe debug log (do not log passwords)
error_log('register.php received: ' . json_encode(array_diff_key($data, array('password' => ''))));

$first_name = trim($data['first_name'] ?? '');
$last_name = trim($data['last_name'] ?? '');
$email = strtolower(trim((string) ($data['email'] ?? '')));
$password = $data['password'] ?? '';
$contact_number = trim($data['contact_number'] ?? '');
$date_of_birth = trim((string) ($data['date_of_birth'] ?? ''));

if (!array_key_exists('gender', $data) || trim((string) ($data['gender'] ?? '')) === '') {
    echo json_encode(["success" => false, "message" => "gender is required"]);
    exit;
}
if ($date_of_birth === '') {
    echo json_encode(["success" => false, "message" => "date_of_birth is required"]);
    exit;
}

$gender = normalize_gender((string) $data['gender']);

if (!$first_name || !$last_name || !$email || !$password || !$contact_number || $date_of_birth === '') {
    echo json_encode(["success" => false, "message" => "Missing required fields"]);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode(["success" => false, "message" => "Invalid email address"]);
    exit;
}

$checkStmt = $conn->prepare("SELECT patient_id FROM patient_auth WHERE LOWER(email) = LOWER(?) LIMIT 1");
$checkStmt->bind_param("s", $email);
$checkStmt->execute();
$checkResult = $checkStmt->get_result();
if ($checkResult->num_rows > 0) {
    echo json_encode(["success" => false, "message" => "Email is already registered"]);
    $checkStmt->close();
    $conn->close();
    exit;
}
$checkStmt->close();

// Use a predictable sequential patient_id format so the same patient can be matched
// reliably across login, profile, and appointment flows.
$conn->begin_transaction();
try {
    $nextIdResult = $conn->query("SELECT CAST(SUBSTRING(patient_id, 2) AS UNSIGNED) AS patient_num FROM patients WHERE patient_id REGEXP '^P[0-9]+$' ORDER BY patient_num DESC LIMIT 1");
    $nextNumber = 1;
    if ($nextIdResult && $nextIdResult->num_rows > 0) {
        $row = $nextIdResult->fetch_assoc();
        $nextNumber = (int) ($row['patient_num'] ?? 0) + 1;
    }
    $patient_id = 'P' . str_pad((string) $nextNumber, 4, '0', STR_PAD_LEFT);
    $name = trim($first_name . ' ' . $last_name);
    $password_hash = password_hash($password, PASSWORD_DEFAULT);

    $patientStmt = $conn->prepare("INSERT INTO patients (patient_id, first_name, last_name, email, password, name, date_of_birth, gender, contact, last_visit, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 'Active', NOW())");
    if ($patientStmt === false) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }
    $patientStmt->bind_param("sssssssss", $patient_id, $first_name, $last_name, $email, $password_hash, $name, $date_of_birth, $gender, $contact_number);

    if (!$patientStmt->execute()) {
        throw new Exception('Patient insert failed: ' . $patientStmt->error);
    }
    $patientStmt->close();

    $authStmt = $conn->prepare("INSERT INTO patient_auth (patient_id, email, password_hash) VALUES (?, ?, ?)");
    if ($authStmt === false) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }
    $authStmt->bind_param("sss", $patient_id, $email, $password_hash);

    if (!$authStmt->execute()) {
        throw new Exception('Auth insert failed: ' . $authStmt->error);
    }
    $authStmt->close();

    $conn->commit();

    echo json_encode([
        "success" => true,
        "message" => "Registration successful",
        "data" => [
            "patient_id" => $patient_id,
            "first_name" => $first_name,
            "last_name" => $last_name,
            "email" => $email,
            "contact_number" => $contact_number,
            "gender" => $gender,
            "date_of_birth" => $date_of_birth,
        ]
    ]);
} catch (Exception $e) {
    $conn->rollback();
    // attempt safe cleanup if patient partially inserted
    if (!empty($patient_id)) {
        $safeId = $conn->real_escape_string($patient_id);
        $conn->query("DELETE FROM patients WHERE patient_id = '$safeId'");
    }
    error_log('register.php error: ' . $e->getMessage());
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}

$conn->close();
?>