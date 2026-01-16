<?php
include 'db_config.php';

$email = $_POST['email'];

$response = [];

$sql = "SELECT fullName, ICNum, phoneNumber, matricNumber, faculty, gender, year, section, course, profile_image 
        FROM students WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);

if ($stmt->execute()) {
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $student = $result->fetch_assoc();

        // Format the response properly
        $student['profile_image'] = !empty($student['profile_image'])
            ? 'http://172.20.10.4/uploads/' . basename($student['profile_image'])
            : null;

        echo json_encode(['success' => true, 'data' => $student]);
    } else {
        echo json_encode(['success' => false, 'message' => 'Student not found.']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Database query failed: ' . $stmt->error]);
}

$conn->close();
?>
