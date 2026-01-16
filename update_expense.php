<?php
include 'db_config.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id = $_POST['id'] ?? '';
    $email = $_POST['email'] ?? '';
    $amount = $_POST['amount'] ?? '';
    $date = $_POST['date'] ?? '';
    $description = $_POST['description'] ?? '';
    $category = $_POST['category'] ?? '';
    $is_tax_deductible = $_POST['is_tax_deductible'] ?? '0';

    if (empty($id) || empty($email) || empty($amount) || empty($date)) {
        echo 'missing_fields';
        exit;
    }

    $stmt = $conn->prepare("UPDATE expenses SET amount = ?, date = ?, description = ?, category = ?, is_tax_deductible = ? WHERE id = ? AND email = ?");
    $stmt->bind_param("dsssdis", $amount, $date, $description, $category, $is_tax_deductible, $id, $email);

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
