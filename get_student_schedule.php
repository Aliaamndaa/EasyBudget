<?php
// Include the database connection config
include('db_config.php');

// Get raw POST data (JSON)
$data = json_decode(file_get_contents('php://input'), true);

// Check if JSON is valid
if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode(['success' => false, 'message' => 'Invalid JSON format']);
    exit;
}

// Get email from the JSON body
$email = $data['email'] ?? null;

// Validate email
if ($email == null) {
    echo json_encode(['success' => false, 'message' => 'Email parameter is missing.']);
    exit;
}

// Create a database connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check for connection errors
if ($conn->connect_error) {
    die(json_encode(['success' => false, 'message' => 'Database connection failed: ' . $conn->connect_error]));
}

// Query to fetch the classes the user is registered for, including day, time, venue, and schedule_id
$query = "
    SELECT 
        ss.subject_name, 
        l.LectName AS lecturer_name,
        t.day,
        t.time,
        t.venue,
        t.schedule_id
    FROM 
        student_subjects ss
    JOIN 
        timetablelect t ON ss.schedule_id = t.schedule_id
    JOIN 
        lecturer l ON l.Staff_ID = t.Staff_ID
    WHERE 
        ss.email = ?";

// Prepare and execute the query
$stmt = $conn->prepare($query);
if (!$stmt) {
    echo json_encode(['success' => false, 'message' => 'Query preparation failed.']);
    exit;
}
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

// Fetch records
$classes = [];
if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $classes[] = [
            'subject_name' => $row['subject_name'],
            'lecturer_name' => $row['lecturer_name'],
            'day' => $row['day'],
            'time' => $row['time'],
            'venue' => $row['venue'],
            'schedule_id' => (int)$row['schedule_id'] // Explicitly cast to integer
        ];
    }
} else {
    echo json_encode(['success' => false, 'message' => 'No schedule found for the given email.']);
    exit;
}

// Return schedule records as JSON
echo json_encode([
    'success' => true,
    'schedule' => $classes
]);

// Close statements and the database connection
$stmt->close();
$conn->close();
?>