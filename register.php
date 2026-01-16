<?php
include('db_config.php');
ini_set('display_errors', 1);
error_reporting(E_ALL);

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $email = $_POST['email'];
    $password = $_POST['password'];

    if (empty($email) || empty($password)) {
        die('Invalid input: Email and password are required.');
    }

    if (strlen($password) < 6) {
        die('Password must be at least 6 characters long.');
    }

    $email = mysqli_real_escape_string($conn, $email);
    $password = mysqli_real_escape_string($conn, $password);

    $checkEmailQuery = "SELECT * FROM userdata WHERE email = '$email'";
    $result = $conn->query($checkEmailQuery);

    if ($result === FALSE) {
        error_log("Query Error: " . $conn->error);
        die("Database error. Please try again later.");
    } elseif ($result->num_rows > 0) {
        die("Email already exists!");
    }

    $hashed_password = password_hash($password, PASSWORD_DEFAULT);
    $sql = "INSERT INTO userdata (email, password) VALUES ('$email', '$hashed_password')";

    if ($conn->query($sql) === TRUE) {
        echo "Registration successful!";
    } else {
        error_log("Insert Error: " . $conn->error);
        die("Error inserting data: " . $conn->error);
    }

    $conn->close();
} else {
    die("Invalid request method. Only POST requests are allowed.");
}
?>
