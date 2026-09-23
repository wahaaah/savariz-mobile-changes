<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    echo json_encode(["success" => false, "message" => "No data received"]);
    exit;
}

$patient_id = $data['patient_id'] ?? null;
$appointment_date = trim($data['appointment_date'] ?? '');
$appointment_time = trim($data['appointment_time'] ?? '');
$provider = trim((string) ($data['provider'] ?? ''));
$appointment_type = trim((string) ($data['appointment_type'] ?? ''));
$rawStatus = trim((string) ($data['status'] ?? $data['appointment_status'] ?? 'Requested'));
$normalizedStatus = strtolower($rawStatus);

if ($normalizedStatus === 'requested' || $normalizedStatus === 'pending' || $normalizedStatus === 'new' || $normalizedStatus === '') {
    $normalizedStatus = 'Requested';
} elseif ($normalizedStatus === 'confirmed' || $normalizedStatus === 'approved' || $normalizedStatus === 'accepted') {
    $normalizedStatus = 'Confirmed';
} elseif ($normalizedStatus === 'cancelled' || $normalizedStatus === 'canceled' || $normalizedStatus === 'rejected' || $normalizedStatus === 'declined') {
    $normalizedStatus = 'Cancelled';
} else {
    $normalizedStatus = ucfirst(strtolower($rawStatus));
}

if (!$patient_id || !$appointment_date || !$appointment_time) {
    echo json_encode(["success" => false, "message" => "Missing required appointment fields"]);
    exit;
}

if ($provider === '' && isset($data['doctor'])) {
    $provider = trim((string) $data['doctor']);
}
if ($appointment_type === '' && isset($data['visit_type'])) {
    $appointment_type = trim((string) $data['visit_type']);
}

$purpose = parse_appointment_purpose($provider, $appointment_type);
if ($purpose === '') {
    $purpose = 'General Consultation';
}

$appointmentStatus = $normalizedStatus === '' ? 'Pending' : $normalizedStatus;

$stmt = $conn->prepare("INSERT INTO appointments (patient_id, appointment_date, appointment_time, purpose_of_visit, appointment_status) VALUES (?, ?, ?, ?, ?)");
$stmt->bind_param("sssss", $patient_id, $appointment_date, $appointment_time, $purpose, $appointmentStatus);

if ($stmt->execute()) {
    echo json_encode([
        "success" => true,
        "message" => "Appointment created successfully",
        "appointment_id" => $stmt->insert_id
    ]);
} else {
    echo json_encode(["success" => false, "message" => $stmt->error]);
}

$stmt->close();
$conn->close();
?>