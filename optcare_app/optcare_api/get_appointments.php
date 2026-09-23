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

$stmt = $conn->prepare("SELECT appointment_id, patient_id, appointment_date, appointment_time, purpose_of_visit, appointment_status, created_at FROM appointments WHERE patient_id = ? ORDER BY appointment_date, appointment_time");
$stmt->bind_param("s", $patient_id);
$stmt->execute();
$result = $stmt->get_result();
$appointments = [];
while ($row = $result->fetch_assoc()) {
    $appointments[] = normalize_appointment_record($row);
}

echo json_encode(["success" => true, "data" => $appointments]);

$stmt->close();
$conn->close();
?>