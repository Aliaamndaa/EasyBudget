<?php
include 'db_config.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

// Create a database connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check for connection errors
if ($conn->connect_error) {
    die(json_encode(['success' => false, 'message' => "Database connection failed: " . $conn->connect_error]));
}

// Get the raw POST data
$data = json_decode(file_get_contents('php://input'), true);

// Extract the email from the POST data
$email = $data['email'] ?? null;

if (!$email) {
    echo json_encode(['success' => false, 'message' => 'Email is required']);
    exit;
}

// Debugging - Log the received email
error_log("Received email: " . $email);

// SQL query to fetch subject name and lecturer name based on the email
$query = "
    SELECT 
        ss.subject_name, 
        l.LectName AS lecturer_name
    FROM 
        student_subjects ss
    JOIN 
        timetablelect tl ON ss.schedule_id = tl.schedule_id
    JOIN 
        lecturer l ON l.Staff_ID = tl.Staff_ID
    WHERE 
        ss.email = ?
";

// Prepare and execute the query
$stmt = $conn->prepare($query);
$stmt->bind_param("s", $email);
if (!$stmt->execute()) {
    error_log("SQL Error: " . $stmt->error);
}

$result = $stmt->get_result();

// Check if there are any results
if ($result->num_rows > 0) {
    $classes = [];
    while ($row = $result->fetch_assoc()) {
        $classes[] = [
            'subject_name' => $row['subject_name'],
            'lecturer_name' => $row['lecturer_name'],
        ];
    }

    // Return the classes data in JSON format
    echo json_encode(['success' => true, 'classes' => $classes]);
} else {
    // If no results found
    echo json_encode(['success' => false, 'message' => 'No classes found for the given email']);
}

// Close the statement and connection
$stmt->close();
$conn->close();
?>
