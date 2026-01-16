<?php
header('Content-Type: application/json'); // Set header for JSON response

// Include your database configuration file
include('db_config.php');

// Safely fetch POST parameters. Use null coalescing operator (??) for optional fields.
$email = $_POST['email'] ?? null;
$amount = $_POST['amount'] ?? null;
$category = $_POST['category'] ?? null;
$description = $_POST['description'] ?? ''; // Default to empty string if null
$date = $_POST['date'] ?? null;
$receipt_number = $_POST['receipt_number'] ?? ''; // New optional field
$merchant_name = $_POST['merchant_name'] ?? '';  // New optional field
$payment_method = $_POST['payment_method'] ?? ''; // New optional field

// Basic validation for required fields
if ($email && $amount && $category && $date) {
    // Prepare and execute the INSERT query with all columns
    // The 's' type for bind_param should be 's' for string (email, category, description, date, receipt_number, merchant_name, payment_method)
    // and 'd' for double/decimal (amount)
    $query = "INSERT INTO tax_claims (email, amount, category, description, claim_date, receipt_number, merchant_name, payment_method) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($query);

    if ($stmt === false) {
        // Handle prepare error
        echo json_encode(["error" => "SQL Prepare Error: " . $conn->error]);
        $conn->close();
        exit();
    }

    $stmt->bind_param("sdssssss", $email, $amount, $category, $description, $date, $receipt_number, $merchant_name, $payment_method);

    if ($stmt->execute()) {
        echo "success"; // Simple success message
    } else {
        // Handle execute error
        echo json_encode(["error" => "Execute Error: " . $stmt->error]);
    }

    $stmt->close();
} else {
    // Return an error if required parameters are missing
    echo json_encode(["error" => "Missing required parameters (email, amount, category, date)."]);
}

$conn->close();
?>