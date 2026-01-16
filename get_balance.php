<?php
include('db_config.php');

$email = $_POST['email'];

if (!empty($email)) {
    // Total income
    $stmtIncome = $conn->prepare("SELECT SUM(amount) AS total_income FROM income WHERE email = ?");
    $stmtIncome->bind_param("s", $email);
    $stmtIncome->execute();
    $resultIncome = $stmtIncome->get_result()->fetch_assoc();
    $totalIncome = $resultIncome['total_income'] ?? 0;

    // Total expenses
    $stmtExpense = $conn->prepare("SELECT SUM(amount) AS total_expenses FROM expenses WHERE email = ?");
    $stmtExpense->bind_param("s", $email);
    $stmtExpense->execute();
    $resultExpense = $stmtExpense->get_result()->fetch_assoc();
    $totalExpenses = $resultExpense['total_expenses'] ?? 0;

    echo json_encode([
        'income' => $totalIncome,
        'expenses' => $totalExpenses
    ]);

    $stmtIncome->close();
    $stmtExpense->close();
} else {
    echo json_encode([
        'income' => 0,
        'expenses' => 0
    ]);
}

$conn->close();
?>
