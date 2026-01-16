<?php
header('Content-Type: application/json');

// Get the data from the POST request
$data = json_decode(file_get_contents("php://input"));

// Ensure the necessary parameters are available
if (isset($data->email) && isset($data->subject_name)) {
    $email = $data->email;
    $subject_name = $data->subject_name;

    // Database connection
    $servername = "localhost"; // Replace with your database server
    $username = "root"; // Replace with your database username
    $password = ""; // Replace with your database password
    $dbname = "smartattendance"; // Replace with your database name

    // Create connection
    $conn = new mysqli($servername, $username, $password, $dbname);

    // Check for connection errors
    if ($conn->connect_error) {
        echo json_encode(['success' => false, 'message' => 'Database connection failed: ' . $conn->connect_error]);
        exit();
    }

    // Prepare SQL query to delete the subject from student_subjects table
    $stmt = $conn->prepare("DELETE FROM student_subjects WHERE email = ? AND subject_name = ?");
    $stmt->bind_param("ss", $email, $subject_name);

    // Execute the query
    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Subject deleted successfully.']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Failed to delete subject.']);
    }

    // Close connection
    $stmt->close();
    $conn->close();
} else {
    echo json_encode(['success' => false, 'message' => 'Invalid data received.']);
}
?>
