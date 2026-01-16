<?php
include('db_config.php');

header('Content-Type: application/json'); // Set response to JSON

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    // Get login credentials
    $email = $_POST['email'];
    $password = $_POST['password'];

    // Check if email exists in the database
    $checkEmailQuery = "SELECT * FROM userdata WHERE email = '$email'";
    $result = $conn->query($checkEmailQuery);

    if ($result->num_rows > 0) {
        // Fetch the stored password hash
        $row = $result->fetch_assoc();
        $storedPassword = $row['password'];

        // Verify the password
        if (password_verify($password, $storedPassword)) {
            // Successful login
            echo json_encode(["status" => "success"]);
        } else {
            // Incorrect password
            echo json_encode(["status" => "error", "message" => "Incorrect password!"]);
        }
    } else {
        // Email not found
        echo json_encode(["status" => "error", "message" => "Email not found!"]);
    }

    $conn->close();
} else {
    // Invalid request method
    echo json_encode(["status" => "error", "message" => "Invalid request method."]);
}
?>
