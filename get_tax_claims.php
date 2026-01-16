<?php
header('Content-Type: application/json'); // Set header for JSON response

// Include your database configuration file
include('db_config.php');

// Safely fetch GET parameters
$email = $_GET['email'] ?? null;
$date = $_GET['date'] ?? null; // This date parameter is used for yearly filtering

if ($email && $date) {
    // Extract the year from the provided date (e.g., '2024-01-01' -> '2024')
    $year = date('Y', strtotime($date));

    // Prepare and execute query to fetch all claims for the given email and year
    // We are selecting all columns to be sent to the Flutter app
    // --- CHANGED 'id' to 'claim_id' HERE ---
    $query = "SELECT claim_id, category, amount, description, claim_date, receipt_number, merchant_name, payment_method FROM tax_claims WHERE email = ? AND YEAR(claim_date) = ?";
    $stmt = $conn->prepare($query);

    if ($stmt === false) {
        // Handle prepare error
        echo json_encode(["error" => "SQL Prepare Error: " . $conn->error]);
        $conn->close();
        exit();
    }

    $stmt->bind_param("ss", $email, $year); // Bind email and year
    $stmt->execute();
    $result = $stmt->get_result();

    $claims = [];
    while ($row = $result->fetch_assoc()) {
        $claims[] = $row;
    }

    echo json_encode($claims); // Encode the array of claims as JSON

    $stmt->close();
} else {
    // Return an error if required parameters are missing
    echo json_encode(["error" => "Missing required parameters (email or date)."]);
}

$conn->close();
?>