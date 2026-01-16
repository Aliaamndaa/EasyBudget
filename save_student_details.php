<?php
include 'db_config.php';

$email = $_POST['email'];
$fullName = $_POST['fullName'];
$ICNum = $_POST['ICNum'];
$phoneNumber = $_POST['phoneNumber'];
$matricNumber = $_POST['matricNumber'];
$faculty = $_POST['faculty'];
$gender = $_POST['gender'];
$year = $_POST['year'];
$section = $_POST['section'];
$course = $_POST['course'];
$response = [];

// Validate required fields
if (empty($email) || empty($fullName) || empty($matricNumber)) {
    $response['success'] = false;
    $response['message'] = "Required fields are missing.";
    echo json_encode($response);
    exit;
}

// Check for duplicate email or matric number
$checkSql = "SELECT * FROM students WHERE email = ? OR matricNumber = ?";
$checkStmt = $conn->prepare($checkSql);
$checkStmt->bind_param("ss", $email, $matricNumber);
$checkStmt->execute();
$checkResult = $checkStmt->get_result();

if ($checkResult->num_rows > 0) {
    $response['success'] = false;
    $response['message'] = "Student with this email or matric number already exists.";
    echo json_encode($response);
    exit;
}

// Handle file upload (if applicable)
$imagePath = null;
if (isset($_FILES['profileImage']) && $_FILES['profileImage']['error'] === UPLOAD_ERR_OK) {
    $uploadDir = 'C:\\workshop2\\uploads\\'; // Explicit directory path for Windows
    $fileTmpPath = $_FILES['profileImage']['tmp_name'];

    // Ensure the upload directory exists
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }

    // Validate file type and size
    $fileType = mime_content_type($fileTmpPath);
    $allowedMimeTypes = ['image/jpeg', 'image/png'];
    if (!in_array($fileType, $allowedMimeTypes)) {
        $response['success'] = false;
        $response['message'] = "Invalid file type. Only JPEG and PNG files are allowed.";
        echo json_encode($response);
        exit;
    }
    if ($_FILES['profileImage']['size'] > 2 * 1024 * 1024) { // 2MB limit
        $response['success'] = false;
        $response['message'] = "File size exceeds 2MB limit.";
        echo json_encode($response);
        exit;
    }

    // Determine file extension
    $fileExtension = pathinfo($_FILES['profileImage']['name'], PATHINFO_EXTENSION);

    // Use matric number as the file name
    $safeFileName = preg_replace('/[^a-zA-Z0-9\._-]/', '_', $matricNumber); // Sanitize matric number
    $uploadPath = $uploadDir . $safeFileName . '.' . $fileExtension;

    // Move the uploaded file
    if (move_uploaded_file($fileTmpPath, $uploadPath)) {
        $imagePath = $safeFileName . '.' . $fileExtension; // Save the file name with the extension in the database
    } else {
        $response['success'] = false;
        $response['message'] = "Failed to upload the profile image.";
        echo json_encode($response);
        exit;
    }
}

// Insert student details into the database
$sql = "INSERT INTO students (email, fullName, ICNum, phoneNumber, matricNumber, faculty, gender, year, section, course, profile_image)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
$stmt = $conn->prepare($sql);

if ($stmt) {
    $stmt->bind_param("sssssssssss", $email, $fullName, $ICNum, $phoneNumber, $matricNumber, $faculty, $gender, $year, $section, $course, $imagePath);

    if ($stmt->execute()) {
        $response['success'] = true;
        $response['message'] = "Student details saved successfully.";
    } else {
        $response['success'] = false;
        $response['message'] = "Error saving student: " . $stmt->error;
    }
    $stmt->close();
} else {
    $response['success'] = false;
    $response['message'] = "Error preparing statement: " . $conn->error;
}

echo json_encode($response);
$conn->close();
?>
