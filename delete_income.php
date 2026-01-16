<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: text/plain');

include('db_config.php'); 


if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

$id = $_POST['id'] ?? '';
$email = $_POST['email'] ?? '';

if (empty($id) || empty($email)) {
    echo "Error: Missing required data. Please provide ID and email.";
    $conn->close();
    exit();
}


$stmt = $conn->prepare("DELETE FROM income WHERE id = ? AND email = ?");

$stmt->bind_param("is", $id, $email);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo "success";
    } else {
        echo "Error: No record found for ID '$id' and email '$email'.";
    }
} else {
    error_log("Failed to delete income: " . $stmt->error);
    echo "Error: Failed to delete income due to a server error.";
}

$stmt->close();
$conn->close();
?>