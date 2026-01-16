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
    echo json_encode(['success' => false, 'message' => 'Invalid JSON format']);
    exit;
}

$email = $data['email'] ?? null;
$selectedSubjects = $data['selectedSubjects'] ?? [];

if (!$email || empty($selectedSubjects)) {
    echo json_encode(['success' => false, 'message' => 'Email or selected subjects missing']);
    exit;
}

$errors = [];
$alreadyRegistered = [];

$stmt_check = $conn->prepare("
    SELECT ss.id 
    FROM student_subjects ss 
    JOIN timetablelect t ON ss.schedule_id = t.schedule_id 
    WHERE ss.email = ? AND t.schedule_id = ?
");

$stmt_insert = $conn->prepare("
    INSERT INTO student_subjects (email, schedule_id, subject_name) 
    VALUES (?, ?, ?)
");

$stmt_fetch_registered = $conn->prepare("
    SELECT t.subject 
    FROM student_subjects ss 
    JOIN timetablelect t ON ss.schedule_id = t.schedule_id 
    WHERE ss.email = ?
");

$stmt_fetch_registered->bind_param("s", $email);
$stmt_fetch_registered->execute();
$registeredResult = $stmt_fetch_registered->get_result();

// Collect already registered subjects
$registeredSubjects = [];
while ($row = $registeredResult->fetch_assoc()) {
    $registeredSubjects[] = $row['subject'];
}

foreach ($selectedSubjects as $subjectCode) {
    // Get schedule_id and subject_name from subject_code
    $stmt_subject = $conn->prepare("SELECT schedule_id, subject FROM timetablelect WHERE subject = ?");
    $stmt_subject->bind_param("s", $subjectCode);
    $stmt_subject->execute();
    $result = $stmt_subject->get_result();
    
    if ($result->num_rows > 0) {
        $subject = $result->fetch_assoc();
        $scheduleId = $subject['schedule_id'];
        $subjectName = $subject['subject'];

        // Check if the student is already registered for the subject
        if (in_array($subjectCode, $registeredSubjects)) {
            $alreadyRegistered[] = $subjectCode;  // Subject already registered
        } else {
            // Register the subject
            $stmt_insert->bind_param("sis", $email, $scheduleId, $subjectName); // Insert subject name
            if (!$stmt_insert->execute()) {
                $errors[] = "Error registering subject $subjectCode";
            }
        }
    } else {
        $errors[] = "Subject $subjectCode not found";
    }
}

$stmt_check->close();
$stmt_insert->close();
$stmt_fetch_registered->close();
$conn->close();

// Return response based on success or errors
if (empty($errors)) {
    if (empty($alreadyRegistered)) {
        echo json_encode(['success' => true, 'message' => 'Subjects registered successfully']);
    } else {
        echo json_encode([
            'success' => false, 
            'message' => 'The following subjects were already registered and could not be added again: ' . implode(", ", $alreadyRegistered)
        ]);
    }
} else {
    echo json_encode(['success' => false, 'message' => implode(", ", $errors)]);
}
?>