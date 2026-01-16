<?php
include 'db_connect.php';

$email = $_POST['email'];
$title = $_POST['title'];
$amount = $_POST['amount'];
$due_date = $_POST['due_date'];

$sql = "INSERT INTO bills (email, title, amount, due_date) VALUES (?, ?, ?, ?)";
$stmt = $conn->prepare($sql);
$stmt->bind_param("ssds", $email, $title, $amount, $due_date);
$stmt->execute();

if ($stmt->affected_rows > 0) {
    echo "success";
} else {
    echo "error";
}
?>
