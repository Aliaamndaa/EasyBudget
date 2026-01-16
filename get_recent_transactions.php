<?php
include('db_config.php');

$email = $_POST['email'] ?? '';

function getTransactions($conn, $email, $table) {
    $query = "SELECT *, '$table' AS type FROM $table WHERE email = ?";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    $transactions = array();
    while ($row = $result->fetch_assoc()) {
        $transactions[] = $row;
    }
    $stmt->close();
    return $transactions;
}

$expenses = getTransactions($conn, $email, 'expenses');
$income = getTransactions($conn, $email, 'income');

$transactions = array_merge($expenses, $income);

// Sort descending by date (most recent first)
usort($transactions, function($a, $b) {
    return strtotime($b['date']) - strtotime($a['date']);
});

// Optional: limit to last 5 transactions
$transactions = array_slice($transactions, 0, 5);

header('Content-Type: application/json');
echo json_encode($transactions);

$conn->close();
?>
