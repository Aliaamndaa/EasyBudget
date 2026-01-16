<?php
include('db_config.php');

$email = $_POST['email'] ?? '';

if (!empty($email)) {
    $stmt = $conn->prepare("
        SELECT id, description, date
        FROM expenses
        WHERE email = ? AND (
            description LIKE '%tnb%' OR
            description LIKE '%unifi%' OR
            description LIKE '%astro%' OR
            description LIKE '%maxis%' OR
            description LIKE '%celcom%' OR
            description LIKE '%internet%' OR
            description LIKE '%syabas%'
        )
        ORDER BY date DESC
        LIMIT 20
    ");
    $stmt->bind_param("s", $email);
    $stmt->execute();

    $result = $stmt->get_result();
    $bills = [];

    while ($row = $result->fetch_assoc()) {
        $dueDate = date('Y-m-d', strtotime($row['date'] . ' +30 days'));
        $bills[] = [
            'id' => $row['id'],
            'description' => $row['description'],
            'due_date' => $dueDate
        ];
    }

    echo json_encode($bills);
} else {
    echo json_encode(['error' => 'Missing email']);
}
?>
