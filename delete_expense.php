<?php
include 'db_config.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id = $_POST['id'] ?? '';
    $email = $_POST['email'] ?? '';

    if (empty($id) || empty($email)) {
        echo 'missing_fields';
        exit;
    }

    $stmt = $conn->prepare("DELETE FROM expenses WHERE id = ? AND email = ?");
    $stmt->bind_param("is", $id, $email);

    if ($stmt->execute()) {
        echo 'success';
    } else {
        echo 'error';
    }

    $stmt->close();
    $conn->close();
} else {
    echo 'invalid_request';
}
?>
