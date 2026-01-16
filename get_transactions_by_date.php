<?php
// Include database connection
include('db_config.php');

$email = $_POST['email'];
$date = $_POST['date']; // Date in yyyy-MM-dd format

// Function to fetch transactions from a table for a specific date
function getTransactionsByDate($conn, $email, $table, $date) {
    $query = "SELECT *, '$table' AS type FROM $table WHERE email = ? AND DATE(date) = ?";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("ss", $email, $date);
    $stmt->execute();
    $result = $stmt->get_result();
    $transactions = array();
    while ($row = $result->fetch_assoc()) {
        $transactions[] = $row;
    }
    $stmt->close();
    return $transactions;
}
//get transactions from both tables
$expenses = getTransactionsByDate($conn, $email, 'expenses', $date);
$income = getTransactionsByDate($conn, $email, 'income', $date);

// Merge the results.
$transactions = array_merge($expenses, $income);

// Return the transactions as JSON
echo json_encode($transactions);

$conn->close();
?>
