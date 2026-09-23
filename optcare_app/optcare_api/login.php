<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

 $rawInput = file_get_contents("php://input");
 // Detailed debug logging to help track empty-body issues from clients
 error_log("[login.php] REQUEST_METHOD=" . ($_SERVER['REQUEST_METHOD'] ?? '')); 
 $hdrs = function_exists('getallheaders') ? getallheaders() : [];
 error_log('[login.php] HEADERS: ' . json_encode($hdrs));
 error_log("[login.php] raw input length: " . strlen($rawInput));
 error_log("[login.php] raw input content: " . $rawInput);
 error_log("[login.php] \\$_POST: " . json_encode($_POST));
 error_log("[login.php] \\$_GET: " . json_encode($_GET));
 // Prefer JSON body, but fall back to form-encoded POST if present
 $data = null;
 if ($rawInput !== null && trim($rawInput) !== '') {
     $data = json_decode($rawInput, true);
 }
 if ($data === null && !empty($_POST)) {
     // handle application/x-www-form-urlencoded or multipart/form-data
     $data = $_POST;
 }
 if ($data === null) {
     echo json_encode(["success" => false, "message" => "No data received"]);
     exit;
 }

ensure_patient_auth_table($conn);

$email = strtolower(trim((string) ($data['email'] ?? '')));
$password = $data['password'] ?? '';

if (!$email || !$password) {
    echo json_encode(["success" => false, "message" => "Email and password are required"]);
    exit;
}

$stmt = $conn->prepare("SELECT pa.patient_id, pa.email, pa.password_hash, p.name, p.date_of_birth, p.gender, p.contact, p.last_visit, p.created_at, p.status
    FROM patient_auth pa
    LEFT JOIN patients p ON p.patient_id = pa.patient_id
    WHERE LOWER(pa.email) = LOWER(?) LIMIT 1");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();

if (!$user) {
    echo json_encode(["success" => false, "message" => "Invalid credentials"]);
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

$nameParts = split_name($user['name'] ?? '');
$gender = $user['gender'] ?? 'Male';
$dateOfBirth = $user['date_of_birth'] ?? null;

$userRecord = [
    'patient_id' => $user['patient_id'],
    'first_name' => $nameParts['first_name'],
    'last_name' => $nameParts['last_name'],
    'email' => $user['email'],
    'date_of_birth' => $dateOfBirth,
    'gender' => $gender,
    'contact_number' => $user['contact'] ?? '',
    'created_at' => $user['created_at'] ?? $user['last_visit'] ?? null,
];

unset($user['password_hash']);

echo json_encode(["success" => true, "message" => "Login successful", "data" => $userRecord]);

$stmt->close();
$conn->close();
?>