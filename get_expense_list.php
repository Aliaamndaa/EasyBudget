<?php
header('Content-Type: application/json');
include('db_config.php');

$email = $_POST['email'];

if (!empty($email)) {
    $stmt = $conn->prepare("SELECT amount, category, description, date FROM expenses WHERE email = ? ORDER BY date DESC");
    $stmt->bind_param("s", $email);

    if ($stmt->execute()) {
        $result = $stmt->get_result();
        $expenses = [];

        while ($row = $result->fetch_assoc()) {
            $expenses[] = $row;
        }

        echo json_encode($expenses);
    } else {
        echo json_encode(["error" => "Query failed"]);
    }

    $stmt->close();
} else {
    echo json_encode(["error" => "Missing email"]);
}

$conn->close();
?>
