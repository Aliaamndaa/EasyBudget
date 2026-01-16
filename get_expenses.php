<?php
include 'db_config.php'; // Ensure this connects to your DB

$email = $_GET['email'];

$sql = "SELECT SUM(amount) AS expenses FROM expenses WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();

$expenses = $row['expenses'] ?? 0;

echo json_encode(["expenses" => $expenses]);

$conn->close();
?>