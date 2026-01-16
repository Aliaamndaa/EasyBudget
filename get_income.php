<?php
include 'db_config.php'; // Ensure this connects to your DB

$email = $_GET['email'];

$sql = "SELECT SUM(amount) AS income FROM income WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();
$row = $result->fetch_assoc();

$income = $row['income'] ?? 0;

echo json_encode(["income" => $income]);

$conn->close();
?>
