<?php
// Include database connection configuration
include('db_config.php');

// Get email from POST request
$email = $_POST['email'] ?? null; // Replace this with actual user input
$status = $_POST['status'] ?? 'present'; // Default to 'present' if not provided

// Validate email
if ($email == null) {
    echo json_encode(['success' => false, 'message' => 'Email parameter is missing.']);
    exit;
}

// Create a database connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check for connection errors
if ($conn->connect_error) {
    die(json_encode(['success' => false, 'message' => "Database connection failed: " . $conn->connect_error]));
}

// SQL query to fetch attendance records
$query = "
    SELECT 
        tl.subject AS subject_name, 
        l.LectName AS lecturer_name, 
        a.status, 
        a.attendance_date
    FROM 
        attendance a
    JOIN 
        timetablelect tl ON a.schedule_id = tl.schedule_id
    JOIN 
        lecturer l ON tl.Staff_ID = l.Staff_ID
    WHERE 
        a.student_email = ? 
        AND a.status = ?";

// Prepare the SQL statement
$stmt = $conn->prepare($query);

if (!$stmt) {
    echo json_encode(['success' => false, 'message' => 'Query preparation failed.']);
    exit;
}

// Bind parameters
$stmt->bind_param("ss", $email, $status);

// Execute the query
$stmt->execute();
$result = $stmt->get_result();

// Fetch records
$attendanceRecords = [];
if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $attendanceRecords[] = [
            'subject_name' => $row['subject_name'],
            'lecturer_name' => $row['lecturer_name'],
            'status' => $row['status'],
            'attendance_date' => $row['attendance_date']
        ];
    }
}

// Output the results as JSON
echo json_encode([
    'success' => true,
    'attendance_records' => $attendanceRecords
]);

// Close the statement and connection
$stmt->close();
$conn->close();
?>