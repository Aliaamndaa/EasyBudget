<?php
include('db_config.php'); // adjust if needed

$email = $_POST['email'];
$year = $_POST['year'] ?? null;

if (!empty($email) && !empty($year)) {
    $stmt = $conn->prepare("
        SELECT MONTH(date) AS month, SUM(amount) AS total
        FROM expenses
        WHERE email = ? AND YEAR(date) = ?
        GROUP BY MONTH(date)
        ORDER BY MONTH(date)
    ");
    $stmt->bind_param("si", $email, $year);
    $stmt->execute();

    $result = $stmt->get_result();
    $data = [];

    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }

    echo json_encode($data);
} else {
    echo json_encode(["error" => "Missing email or year"]);
}
?>
