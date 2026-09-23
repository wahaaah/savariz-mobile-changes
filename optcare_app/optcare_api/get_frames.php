<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

ensure_frames_table($conn);

$sql = "SELECT frame_id, name, category, description, price, COALESCE(image_2d_url, image_url) AS image_url, stock_quantity AS stock FROM frames ORDER BY name ASC";
$result = $conn->query($sql);

$frames = [];
while ($row = $result->fetch_assoc()) {
    $frames[] = normalize_frame_record($row);
}

echo json_encode([
    "success" => true,
    "data" => $frames
]);

$conn->close();
?>