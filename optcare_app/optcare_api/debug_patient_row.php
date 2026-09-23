<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

$patient_id = $_GET['patient_id'] ?? null;
if (!$patient_id) {
    echo json_encode(['success' => false, 'message' => 'patient_id is required']);
    exit;
}

$stmt = $conn->prepare("SELECT * FROM patients WHERE patient_id = ? LIMIT 1");
$stmt->bind_param('s', $patient_id);
$stmt->execute();
$res = $stmt->get_result();
$patient = $res->fetch_assoc();
$stmt->close();

$stmt2 = $conn->prepare("SELECT * FROM patient_auth WHERE patient_id = ? LIMIT 1");
$stmt2->bind_param('s', $patient_id);
$stmt2->execute();
$res2 = $stmt2->get_result();
$auth = $res2->fetch_assoc();
$stmt2->close();

echo json_encode(['success' => true, 'patient' => $patient, 'patient_auth' => $auth]);

$conn->close();

?>
