<?php
header('Content-Type: application/json');
include 'db.php';

if (!isset($_POST['email'], $_POST['date'])) {
    http_response_code(400);
    echo json_encode(["error" => "Missing parameters"]);
    exit;
}

$email = $_POST['email'];
$date = $_POST['date'];

// Validate email
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(["error" => "Invalid email"]);
    exit;
}

$query = "SELECT amount, category, description, date FROM expenses WHERE email = ? AND DATE(date) = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("ss", $email, $date);
$stmt->execute();
$result = $stmt->get_result();

$transactions = [];
while ($row = $result->fetch_assoc()) {
    $transactions[] = $row;
}

echo json_encode($transactions);
?>
