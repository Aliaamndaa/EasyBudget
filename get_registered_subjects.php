<?php
include 'db_config.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die(json_encode(['success' => false, 'message' => "Database connection failed: " . $conn->connect_error]));
}

// Decode the JSON payload
$data = json_decode(file_get_contents('php://input'), true);

if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode(['success' => false, 'message' => 'Invalid JSON format: ' . json_last_error_msg()]);
    exit;
}

// Check for missing parameters
$email = $data['email'] ?? null;

if (!$email) {
    echo json_encode(['success' => false, 'message' => 'Email missing']);
    exit;
}

// Fetch the registered subjects
$stmt_fetch_registered = $conn->prepare("
    SELECT t.subject 
    FROM student_subjects ss 
    JOIN timetablelect t ON ss.schedule_id = t.schedule_id 
    WHERE ss.email = ?
");
$stmt_fetch_registered->bind_param("s", $email);
$stmt_fetch_registered->execute();
$registeredResult = $stmt_fetch_registered->get_result();

// Collect registered subjects
$registeredSubjects = [];
while ($row = $registeredResult->fetch_assoc()) {
    $registeredSubjects[] = $row['subject'];
}

$stmt_fetch_registered->close();
$conn->close();

// If no subjects are found for the user
if (empty($registeredSubjects)) {
    echo json_encode(['success' => false, 'message' => 'No registered subjects found for this user.']);
    exit;
}

// Return response with the registered subjects
echo json_encode(['success' => true, 'data' => $registeredSubjects]);
?>