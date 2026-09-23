<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    echo json_encode(["success" => false, "message" => "No data received"]);
    exit;
}

$appointment_id = $data['appointment_id'] ?? null;
$patient_id = $data['patient_id'] ?? null;

if (!$appointment_id) {
    echo json_encode(["success" => false, "message" => "appointment_id is required"]);
    exit;
}

if ($patient_id) {
    $stmt = $conn->prepare("UPDATE appointments SET appointment_status = 'Cancelled' WHERE appointment_id = ? AND patient_id = ?");
    $stmt->bind_param("is", $appointment_id, $patient_id);
} else {
    $stmt = $conn->prepare("UPDATE appointments SET appointment_status = 'Cancelled' WHERE appointment_id = ?");
    $stmt->bind_param("i", $appointment_id);
}

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo json_encode(["success" => true, "message" => "Appointment cancelled successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Appointment not found or already cancelled"]);
    }
} else {
    echo json_encode(["success" => false, "message" => $stmt->error]);
}

$stmt->close();
$conn->close();
?>