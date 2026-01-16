<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: text/plain');

include('db_config.php'); // Your database connection file

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

$id = $_POST['id'] ?? '';
$email = $_POST['email'] ?? '';
$amount = $_POST['amount'] ?? '';
$date = $_POST['date'] ?? '';

// Basic validation
if (empty($id) || empty($email) || empty($amount) || empty($date)) {
    echo "Error: Missing required data. Please provide ID, email, amount, and date.";
    $conn->close();
    exit();
}

// Validate amount
if (!is_numeric($amount) || $amount <= 0) {
    echo "Error: Invalid amount. Must be a positive number.";
    $conn->close();
    exit();
}

// Validate date format
if (!preg_match("/^\d{4}-\d{2}-\d{2}$/", $date)) {
    echo "Error: Invalid date format. Please use YYYY-MM-DD.";
    $conn->close();
    exit;
}

// Prepare and bind
$stmt = $conn->prepare("UPDATE income SET amount = ?, date = ? WHERE id = ? AND email = ?");
$stmt->bind_param("dsis", $amount, $date, $id, $email);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo "success";
    } else {
        echo "Error: No record found for ID '$id' and email '$email' or no changes made.";
    }
} else {
    error_log("Failed to update income: " . $stmt->error);
    echo "Error: Failed to update income due to a server error.";
}

$stmt->close();
$conn->close();
?>
