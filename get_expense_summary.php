<?php
include('db_config.php');

$email = $_POST['email'];
$month = $_POST['month'] ?? null;
$year = $_POST['year'] ?? null;

if (!empty($email) && !empty($year)) {
    $query = "
        SELECT category, SUM(amount) AS total
        FROM expenses
        WHERE email = ? AND YEAR(date) = ?
    ";

    if ($month) {
        $query .= " AND MONTH(date) = ?";
    }

    $query .= " GROUP BY category";

    $stmt = $month
        ? $conn->prepare($query)
        : $conn->prepare(str_replace(" AND MONTH(date) = ?", "", $query));

    if ($month) {
        $stmt->bind_param("sii", $email, $year, $month);
    } else {
        $stmt->bind_param("si", $email, $year);
    }

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
