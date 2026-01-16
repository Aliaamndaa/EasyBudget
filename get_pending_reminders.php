<?php
include('db_config.php');

$email = $_POST['email'] ?? '';

if (!$email) {
    echo json_encode(['error' => 'Missing email']);
    exit;
}

// You can adjust this logic based on your database structure
$query = "
    SELECT id, description, date
    FROM expenses
    WHERE email = ? 
      AND description LIKE '%bill%' 
      AND date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY)
    ORDER BY date ASC
";

$stmt = $conn->prepare($query);
$stmt->bind_param("s", $email);
$stmt->execute();

$result = $stmt->get_result();
$reminders = [];

while ($row = $result->fetch_assoc()) {
    $reminders[] = $row;
}

echo json_encode($reminders);
?>
