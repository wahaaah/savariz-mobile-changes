<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

$sql = "SELECT p.patient_id, p.name, p.contact, p.last_visit, p.status, pa.email
    FROM patients p
    LEFT JOIN patient_auth pa ON pa.patient_id = p.patient_id
    ORDER BY p.name ASC";
$result = $conn->query($sql);

$patients = [];
while ($row = $result->fetch_assoc()) {
    $nameParts = split_name($row['name'] ?? '');
    $patients[] = [
        'patient_id' => $row['patient_id'],
        'first_name' => $nameParts['first_name'],
        'last_name' => $nameParts['last_name'],
        'email' => $row['email'] ?? '',
        'contact_number' => $row['contact'] ?? '',
        'created_at' => $row['last_visit'] ?? null,
        'status' => $row['status'] ?? 'Active',
    ];
}

echo json_encode($patients);
$conn->close();
?>