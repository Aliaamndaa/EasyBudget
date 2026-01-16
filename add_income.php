<?php
include('db_config.php'); // Make sure this file connects to your DB

// Check if both email and amount are sent
if (isset($_POST['email']) && isset($_POST['amount'])) {
    $email = $_POST['email'];
    $amount = $_POST['amount'];
    $date = date('Y-m-d H:i:s'); // Use current date-time

    // Prepare SQL statement to insert income
    $stmt = $conn->prepare("INSERT INTO income (email, amount, date) VALUES (?, ?, ?)");
    $stmt->bind_param("sds", $email, $amount, $date); // 's' = string, 'd' = double, 's' = string

    if ($stmt->execute()) {
        echo "success"; // Send back "success" to the Flutter app
    } else {
        echo "error: " . $stmt->error; // Show error if insert fails
    }

    $stmt->close();
} else {
    echo "error: Missing email or amount";
}

$conn->close();
?>
