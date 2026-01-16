<?php
include('db_config.php'); // Database connection

if (isset($_POST['email'])) {
    $email = $_POST['email'];

    $stmt = $conn->prepare("SELECT id, amount, date FROM income WHERE email = ? ORDER BY date DESC");
    $stmt->bind_param("s", $email);

    if ($stmt->execute()) {
        $result = $stmt->get_result();
        $incomeList = [];

        while ($row = $result->fetch_assoc()) {
            $incomeList[] = $row;
        }

        echo json_encode($incomeList); // Return as JSON
    } else {
        echo json_encode(["error" => "Failed to fetch income"]);
    }

    $stmt->close();
} else {
    echo json_encode(["error" => "Missing email"]);
}

$conn->close();
?>
