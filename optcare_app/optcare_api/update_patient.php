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
$patient_id = $data['patient_id'] ?? null;
if (!$patient_id) {
    echo json_encode(["success" => false, "message" => "patient_id is required"]);
    exit;
}

// Build a dynamic update to avoid overwriting fields with NULL when not provided
$updates = [];
$types = '';
$params = [];

// Accept either explicit first_name/last_name or a combined 'name'. If the caller
// provided only `name`, derive first/last parts and update both columns so they
// stay in sync.
$first_name = array_key_exists('first_name', $data) ? trim((string) ($data['first_name'] ?? '')) : null;
$last_name = array_key_exists('last_name', $data) ? trim((string) ($data['last_name'] ?? '')) : null;
$providedName = array_key_exists('name', $data) ? trim((string) ($data['name'] ?? '')) : null;

if ($providedName !== null && $providedName !== '') {
    // Derive parts if explicit parts were not provided
    $derived = split_name($providedName);
    if ($first_name === null) $first_name = $derived['first_name'];
    if ($last_name === null) $last_name = $derived['last_name'];
    // Ensure we update the combined name column as provided
    $updates[] = 'name = ?';
    $types .= 's';
    $params[] = $providedName;
}

// Update first_name/last_name columns directly when available
if ($first_name !== null) {
    $updates[] = 'first_name = ?';
    $types .= 's';
    $params[] = $first_name;
}
if ($last_name !== null) {
    $updates[] = 'last_name = ?';
    $types .= 's';
    $params[] = $last_name;
}

// If first/last were provided but combined name was not, compute combined name
// using existing DB values for any missing parts so we don't overwrite with blanks.
if (($first_name !== null || $last_name !== null) && ($providedName === null || $providedName === '')) {
    // fetch existing first_name/last_name
    $existingStmt = $conn->prepare("SELECT first_name, last_name FROM patients WHERE patient_id = ? LIMIT 1");
    if ($existingStmt) {
        $existingStmt->bind_param('s', $patient_id);
        $existingStmt->execute();
        $er = $existingStmt->get_result();
        $existingRow = $er->fetch_assoc();
        $existingStmt->close();
    } else {
        $existingRow = ['first_name' => '', 'last_name' => ''];
    }

    $finalFirst = $first_name !== null ? $first_name : ($existingRow['first_name'] ?? '');
    $finalLast = $last_name !== null ? $last_name : ($existingRow['last_name'] ?? '');
    $computedName = trim(($finalFirst ? $finalFirst : '') . ' ' . ($finalLast ? $finalLast : ''));
    if ($computedName !== '') {
        $updates[] = 'name = ?';
        $types .= 's';
        $params[] = $computedName;
    }
}

// Contact
if (array_key_exists('contact_number', $data)) {
    $contact_number = trim((string) ($data['contact_number'] ?? ''));
    $updates[] = 'contact = ?';
    $types .= 's';
    $params[] = $contact_number;
}

// DOB + Gender: update only when explicitly provided.
$date_of_birth = array_key_exists('date_of_birth', $data) ? trim((string) ($data['date_of_birth'] ?? '')) : null;
if ($date_of_birth !== null && $date_of_birth !== '') {
    $updates[] = 'date_of_birth = ?';
    $types .= 's';
    $params[] = $date_of_birth;
}

if (array_key_exists('gender', $data)) {
    $gender = normalize_gender($data['gender'] ?? 'Other');
    $updates[] = 'gender = ?';
    $types .= 's';
    $params[] = $gender;
}

// If email provided, update the patients.email column as well so both tables stay in sync
if (array_key_exists('email', $data) && trim((string)$data['email']) !== '') {
    $email = trim((string)$data['email']);
    $updates[] = 'email = ?';
    $types .= 's';
    $params[] = $email;
}

if (count($updates) === 0 && !array_key_exists('email', $data)) {
    echo json_encode(["success" => false, "message" => "No updatable fields provided"]);
    $conn->close();
    exit;
}

// Start transaction to keep updates atomic with potential email update
$conn->begin_transaction();
try {
    if (count($updates) > 0) {
        $sql = 'UPDATE patients SET ' . implode(', ', $updates) . ' WHERE patient_id = ?';
        $types .= 's';
        $params[] = $patient_id;

        $stmt = $conn->prepare($sql);
        if ($stmt === false) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }

        // bind_param requires references
        $bind_names = [];
        $bind_names[] = $types;
        for ($i = 0; $i < count($params); $i++) {
            $bind_name = 'bind' . $i;
            $$bind_name = $params[$i];
            $bind_names[] = &$$bind_name;
        }
        call_user_func_array([$stmt, 'bind_param'], $bind_names);

        if (!$stmt->execute()) {
            throw new Exception('Execute failed: ' . $stmt->error);
        }
        $stmt->close();
    }

    if (array_key_exists('email', $data) && trim((string)$data['email']) !== '') {
        $email = trim((string)$data['email']);
        $emailStmt = $conn->prepare("UPDATE patient_auth SET email = ? WHERE patient_id = ?");
        if ($emailStmt === false) {
            throw new Exception('Prepare failed: ' . $conn->error);
        }
        $emailStmt->bind_param("ss", $email, $patient_id);
        if (!$emailStmt->execute()) {
            throw new Exception('Execute failed: ' . $emailStmt->error);
        }
        $emailStmt->close();
    }

    $conn->commit();

    // Return the updated name fields so the client can confirm what changed
    $selectStmt = $conn->prepare("SELECT first_name, last_name, name, contact, date_of_birth FROM patients WHERE patient_id = ? LIMIT 1");
    if ($selectStmt) {
        $selectStmt->bind_param('s', $patient_id);
        $selectStmt->execute();
        $res = $selectStmt->get_result();
        $updated = $res->fetch_assoc();
        $selectStmt->close();
    } else {
        $updated = null;
    }

    echo json_encode(["success" => true, "message" => "Patient updated successfully", "updated" => $updated]);
} catch (Exception $e) {
    $conn->rollback();
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}

$conn->close();