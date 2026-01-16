<?php
// Include database connection
include('db_config.php');

$email = $_POST['email']; // Email from the Flutter app

// Query to get all transactions for the user
$query = "SELECT * FROM transactions WHERE user_email = ? ORDER BY date DESC";

// Prepare the query
if ($stmt = $conn->prepare($query)) {
    // Bind the parameter
    $stmt->bind_param("s", $email);

    // Execute the statement
    $stmt->execute();
    $result = $stmt->get_result();

    // Fetch all the transactions
    $transactions = array();
    while ($row = $result->fetch_assoc()) {
        $transactions[] = $row;
    }

    // Return the transactions as JSON
    echo json_encode($transactions);

    // Close the statement and connection
    $stmt->close();
} else {
    echo json_encode(["error" => "Failed to execute query."]);
}

$conn->close();
?>
