<?php
include('db_config.php');

$email = $_POST['email'] ?? '';
$description = $_POST['description'] ?? '';
$due_date = $_POST['due_date'] ?? '';

if (empty($email) || empty($description) || empty($due_date)) {
    echo json_encode(["error" => "Missing data"]);
    exit;
}

// Calculate new snoozed date (2 days later)
$snoozedDate = date('Y-m-d', strtotime($due_date . ' +2 days'));

$stmt = $conn->prepare("
    UPDATE expenses 
    SET date = ?
    WHERE email = ? AND description = ? AND date = ?
");

$stmt->bind_param("ssss", $snoozedDate, $email, $description, $due_date);

if ($stmt->execute()) {
    echo "success";
} else {
    echo "failed";
}
?>
