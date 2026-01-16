<?php
include 'db_config.php';

$response = [];
$sql = "SELECT name, profile_image FROM students";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    $response['success'] = true;
    $response['data'] = [];
    while ($row = $result->fetch_assoc()) {
        $response['data'][] = [
            'name' => $row['name'],
            'image_path' => $row['profile_image']
        ];
    }
} else {
    $response['success'] = false;
    $response['message'] = "No records found.";
}

echo json_encode($response);
$conn->close();
?>