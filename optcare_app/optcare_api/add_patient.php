<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    echo json_encode(["success"=> false, "message" => "No data received"]);
    exit;
}

// This endpoint was creating patient rows with legacy/mismatched columns.
// To avoid accidental malformed rows, require callers to use register.php
// which inserts both patients and patient_auth atomically.

error_log('add_patient.php was called. Rejecting legacy usage. Payload keys: ' . json_encode(array_keys($data ?: [])));
echo json_encode(["success" => false, "message" => "Deprecated endpoint. Use register.php to create patients"]); 
$conn->close();
?>