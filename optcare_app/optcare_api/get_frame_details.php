<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include "db_connect.php";

ensure_frames_table($conn);

$frame_id = $_GET['frame_id'] ?? null;

if (!$frame_id) {
    echo json_encode([
        "success" => false,
        "message" => "frame_id is required"
    ]);
    exit;
}

$stmt = $conn->prepare("SELECT frame_id, name, category, description, price, image_2d_url AS image_url, stock_quantity AS stock FROM frames WHERE frame_id = ?");
$stmt->bind_param("i", $frame_id);
$stmt->execute();
$result = $stmt->get_result();
$frame = $result->fetch_assoc();

if ($frame) {
    echo json_encode([
        "success" => true,
        "data" => normalize_frame_record($frame)
    ]);
} else {
    echo json_encode([
        "success" => false,
        "message" => "Frame not found"
    ]);
}

$stmt->close();
$conn->close();
?>