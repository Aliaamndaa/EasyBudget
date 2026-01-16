<?php
include 'db_config.php';

$email = $_POST['email'];
$year = $_POST['year'];
$section = $_POST['section'];
$course = $_POST['course'];
$response = [];

// Validate required fields
if (empty($email)) {
    $response['success'] = false;
    $response['message'] = "Email is required.";
    echo json_encode($response);
    exit;
}

// Fetch matricNumber from the database using email
$fetchMatricSql = "SELECT matricNumber FROM students WHERE email = ?";
$fetchMatricStmt = $conn->prepare($fetchMatricSql);
$fetchMatricStmt->bind_param("s", $email);
$fetchMatricStmt->execute();
$fetchMatricResult = $fetchMatricStmt->get_result();

if ($fetchMatricResult->num_rows > 0) {
    $matricNumber = $fetchMatricResult->fetch_assoc()['matricNumber'];
} else {
    $response['success'] = false;
    $response['message'] = "Student not found. Cannot retrieve matriculation number.";
    echo json_encode($response);
    exit;
}
$fetchMatricStmt->close();

// Check if a file was uploaded
$imagePath = null;
if (isset($_FILES['profileImage']) && $_FILES['profileImage']['error'] === UPLOAD_ERR_OK) {
    $uploadDir = 'C:\workshop2\uploads'; // Explicit directory path for Windows
    $fileTmpPath = $_FILES['profileImage']['tmp_name'];

    // Ensure the upload directory exists
    if (!is_dir($uploadDir)) {
        if (!mkdir($uploadDir, 0777, true)) {
            $response['success'] = false;
            $response['message'] = "Failed to create upload directory.";
            echo json_encode($response);
            exit;
        }
    }

    // Validate file type and size
    $fileType = mime_content_type($fileTmpPath);
    $allowedMimeTypes = ['image/jpeg', 'image/png'];
    $fileExtension = strtolower(pathinfo($_FILES['profileImage']['name'], PATHINFO_EXTENSION));
    if (!in_array($fileType, $allowedMimeTypes) || !in_array($fileExtension, ['jpg', 'jpeg', 'png'])) {
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

    // Use matricNumber as the file name
    $uniqueFileName = $matricNumber . '.' . $fileExtension;
    $uploadPath = $uploadDir . $uniqueFileName;

    // Move the uploaded file
    if (move_uploaded_file($fileTmpPath, $uploadPath)) {
        // Remove old profile image
        $fetchSql = "SELECT profile_image FROM students WHERE email = ?";
        $fetchStmt = $conn->prepare($fetchSql);
        $fetchStmt->bind_param("s", $email);
        $fetchStmt->execute();
        $fetchResult = $fetchStmt->get_result();
        if ($fetchResult->num_rows > 0) {
            $oldImage = $fetchResult->fetch_assoc()['profile_image'];
            $oldImagePath = $uploadDir . $oldImage;
            if ($oldImage && file_exists($oldImagePath)) {
                unlink($oldImagePath);
            }
        }
        $fetchStmt->close();

        $imagePath = $uniqueFileName; // Save only the new file name to the database
    } else {
        $response['success'] = false;
        $response['message'] = "Failed to upload the profile image.";
        echo json_encode($response);
        exit;
    }
}

// Update student details in the database
if ($imagePath === null) {
    // If no new image was uploaded, don't update the profile_image column
    $sql = "UPDATE students SET year = ?, section = ?, course = ? WHERE email = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssss", $year, $section, $course, $email);
} else {
    // If a new image was uploaded, update the profile_image column
    $sql = "UPDATE students SET year = ?, section = ?, course = ?, profile_image = ? WHERE email = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssss", $year, $section, $course, $imagePath, $email);
}

if ($stmt) {
    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            $response['success'] = true;
            $response['message'] = "Student details updated successfully.";
        } else {
            $response['success'] = false;
            $response['message'] = "No changes made or student not found.";
        }
    } else {
        $response['success'] = false;
        $response['message'] = "Error executing query: " . $stmt->error;
    }
    $stmt->close();
} else {
    $response['success'] = false;
    $response['message'] = "Error preparing statement: " . $conn->error;
}

echo json_encode($response);
$conn->close();
?>
