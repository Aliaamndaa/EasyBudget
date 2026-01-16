<?php
ob_clean(); // Remove any prior output
header('Content-Type: text/plain'); // Force plain text

include('db_config.php');

$email = $_POST['email'];
$amount = $_POST['amount'];
$category = $_POST['category'];
$description = $_POST['description'];
$date = $_POST['date'];

error_log("Received data: " . json_encode($_POST));

if (!empty($email) && !empty($amount) && !empty($category)) {
    $stmt = $conn->prepare("INSERT INTO expenses (email, amount, category, description, date) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("sdsss", $email, $amount, $category, $description, $date);

    if ($stmt->execute()) {
        echo "success";
    } else {
        error_log("Error: " . $stmt->error);
        echo "error";
    }

    $stmt->close();
} else {
    echo "invalid";
}

$conn->close();
?>
