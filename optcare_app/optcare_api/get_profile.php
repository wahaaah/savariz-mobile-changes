<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

$data = json_decode(file_get_contents("php://input"), true);
$patient_id = $data['patient_id'] ?? $_GET['patient_id'] ?? null;

if (!$patient_id) {
    echo json_encode(["success" => false, "message" => "patient_id is required"]);
    exit;
}

$stmt = $conn->prepare("SELECT p.patient_id, p.name, p.date_of_birth, p.gender, p.contact, p.last_visit, p.created_at, p.status, pa.email
    FROM patients p
    LEFT JOIN patient_auth pa ON pa.patient_id = p.patient_id
    WHERE p.patient_id = ? LIMIT 1");
$stmt->bind_param("s", $patient_id);
$stmt->execute();
$result = $stmt->get_result();
$profile = $result->fetch_assoc();

if (!$profile) {
    echo json_encode(["success" => false, "message" => "Profile not found"]);
    $stmt->close();
    $conn->close();
    exit;
}

$nameParts = split_name($profile['name'] ?? '');

// Prefer explicit first_name/last_name columns if present in the patients table
if (isset($profile['first_name']) || isset($profile['last_name'])) {
    $nameParts = [
        'first_name' => $profile['first_name'] ?? ($nameParts['first_name'] ?? ''),
        'last_name' => $profile['last_name'] ?? ($nameParts['last_name'] ?? ''),
    ];
}
$gender = $profile['gender'] ?? 'Male';
$dateOfBirth = $profile['date_of_birth'] ?? null;

$profileData = [
    'patient_id' => $profile['patient_id'],
    'first_name' => $nameParts['first_name'],
    'last_name' => $nameParts['last_name'],
    'email' => $profile['email'] ?? '',
    'date_of_birth' => $dateOfBirth,
    'gender' => $gender,
    'contact_number' => $profile['contact'] ?? '',
    'created_at' => $profile['created_at'] ?? $profile['last_visit'] ?? null,
];

echo json_encode(["success" => true, "data" => $profileData]);

$stmt->close();
$conn->close();
?>