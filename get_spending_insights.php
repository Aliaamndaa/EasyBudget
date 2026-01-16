<?php
include('db_config.php');

$email = $_POST['email'] ?? '';
error_log("DEBUG: Received email for insights: " . ($email ?: "NULL/Empty"));

if (!$email) {
    error_log("DEBUG: Email not provided for spending insights. Exiting.");
    echo json_encode(['error' => 'Email not provided']);
    exit;
}

// --- Date Range Calculation for the Previous Full Calendar Week ---
$today = new DateTime();
$startOfWeek = clone $today;

// Move to the Monday of the *current* week
// For example, if today is Wed, Jun 12, 2025, this becomes Mon, Jun 10, 2025.
$startOfWeek->modify('last monday');

// Now, subtract 7 days to get to the Monday of the *previous* week
// E.g., from Mon, Jun 10, 2025, this becomes Mon, Jun 3, 2025.
$startOfWeek->modify('-7 days');
$startOfWeek->setTime(0, 0, 0); // Set to start of the day

$endOfWeek = clone $startOfWeek;
$endOfWeek->modify('+6 days'); // This makes it the Sunday of the previous week
$endOfWeek->setTime(23, 59, 59); // Set to end of the day

// Format for MySQL
$start = $startOfWeek->format('Y-m-d H:i:s');
$end = $endOfWeek->format('Y-m-d H:i:s');

error_log("DEBUG: Fetching insights for email: $email, from '$start' to '$end'");


// --- Fetch Expenses for the Previous Week ---
$query = "SELECT * FROM expenses WHERE email = ? AND date BETWEEN ? AND ?";
$stmt = $conn->prepare($query);
if (!$stmt) {
    $error_message = "DEBUG: Prepare failed for expenses query: " . $conn->error;
    error_log($error_message);
    echo json_encode(['error' => $error_message]);
    exit;
}
$stmt->bind_param("sss", $email, $start, $end);
$stmt->execute();
$result = $stmt->get_result();

$expenses = [];
while ($row = $result->fetch_assoc()) {
    $expenses[] = $row;
}
$stmt->close();
error_log("DEBUG: Found " . count($expenses) . " expenses for the previous week.");

$total = 0;
$categoryMap = [];
foreach ($expenses as $e) {
    $amount = floatval($e['amount']);
    $category = strtolower($e['category'] ?? 'other'); // Ensure category is string and lowercase
    $total += $amount;
    $categoryMap[$category] = ($categoryMap[$category] ?? 0) + $amount;
}

$insights = [];

function addInsight(&$insights, $message, $icon) {
    $insights[] = ['message' => $message, 'icon' => $icon];
}

// 🧾 Category-Based Patterns
if ($total > 0) {
    foreach ($categoryMap as $cat => $amt) {
        $percent = ($amt / $total) * 100;
        if ($cat === 'food' && $percent > 50) addInsight($insights, "🍔 Most of your spending last week went to food. Meal prep might save more!", "🍔");
        if ($cat === 'entertainment' && $percent > 40) addInsight($insights, "🎮 You’re really treating yourself! Consider balancing with essentials.", "🎮");
        if ($cat === 'shopping' && $percent > 40) addInsight($insights, "🛍 You've been shopping quite a bit. Check if they’re all necessary.", "🛍");
        if ($cat === 'transport' && $percent > 40) addInsight($insights, "🚗 Last week was all about getting around. Carpooling may help cut costs.", "🚗");
        if ($cat === 'utilities' && $percent > 40) addInsight($insights, "💡 Bills were a big chunk last week. Consider reviewing your usage.", "💡");
    }
}

// 📊 Spending Behavior Changes (compared to two weeks ago)
$prevStart = clone $startOfWeek;
$prevStart->modify('-7 days');
$prevEnd = clone $prevStart;
$prevEnd->modify('+6 days'); // Sunday of the week before last
$prevStartStr = $prevStart->format('Y-m-d H:i:s');
$prevEndStr = $prevEnd->format('Y-m-d H:i:s');

error_log("DEBUG: Fetching previous week's expenses from '$prevStartStr' to '$prevEndStr'");

$prevQuery = "SELECT SUM(amount) as total FROM expenses WHERE email = ? AND date BETWEEN ? AND ?";
$prevStmt = $conn->prepare($prevQuery);
if (!$prevStmt) {
    $error_message = "DEBUG: Prepare failed for previous week expense query: " . $conn->error;
    error_log($error_message);
    $prevTotal = 0; // Set to 0 to prevent further errors
} else {
    $prevStmt->bind_param("sss", $email, $prevStartStr, $prevEndStr);
    $prevStmt->execute();
    $prevResult = $prevStmt->get_result()->fetch_assoc();
    $prevTotal = floatval($prevResult['total'] ?? 0);
    $prevStmt->close();
    error_log("DEBUG: Previous week's total expenses: $prevTotal");
}

if ($total > $prevTotal && $prevTotal > 0) addInsight($insights, "📈 You spent more than the week before last. Keep an eye on patterns.", "📈");
elseif ($total < $prevTotal && $total > 0) addInsight($insights, "📉 Nice! You spent less last week than the week before.", "📉");
elseif ($total == 0 && $prevTotal == 0) addInsight($insights, "✨ Consistent zero spending for the past two weeks. Great job!", "✨");
elseif ($total == 0 && $prevTotal > 0) addInsight($insights, "🧘 You didn’t spend anything last week. Impressive discipline!", "🧘");


// 💵 Income vs Expenses for the previous week
$incomeQuery = "SELECT SUM(amount) as total FROM income WHERE email = ? AND date BETWEEN ? AND ?";
$incomeStmt = $conn->prepare($incomeQuery);
if (!$incomeStmt) {
    $error_message = "DEBUG: Prepare failed for income query: " . $conn->error;
    error_log($error_message);
    $incomeTotal = 0; // Set to 0 to prevent further errors
} else {
    $incomeStmt->bind_param("sss", $email, $start, $end);
    $incomeStmt->execute();
    $incomeResult = $incomeStmt->get_result()->fetch_assoc();
    $incomeTotal = floatval($incomeResult['total'] ?? 0);
    $incomeStmt->close();
    error_log("DEBUG: Previous week's total income: $incomeTotal");
}


if ($incomeTotal == 0) addInsight($insights, "💡 No income logged for last week. Don’t forget to record it.", "💡");
elseif ($total > $incomeTotal) addInsight($insights, "⚠️ Last week, you spent more than you earned. Review your budget.", "⚠️");
elseif ($incomeTotal > $total && $total > 0) addInsight($insights, "🎉 Last week, you saved money! Keep it up!", "🎉");
elseif ($incomeTotal > $total && $total == 0 && $incomeTotal > 0) addInsight($insights, "💰 Great job! You had income but no expenses last week.","💰");


// 🎯 Goal Suggestions
$otherCount = $categoryMap['other'] ?? 0;
if ($otherCount > 0) addInsight($insights, "🧩 Try categorizing your expenses for better insights.", "🧩");

// No tax-deductible check
$taxDeductibleFound = false;
foreach ($expenses as $e) {
    if (isset($e['is_tax_deductible']) && $e['is_tax_deductible'] == 1) {
        $taxDeductibleFound = true;
        break;
    }
}
if (!$taxDeductibleFound) {
    addInsight($insights, "📄 Consider tracking tax-relief expenses to reduce burden.", "📄");
}

error_log("DEBUG: Total insights generated: " . count($insights));
echo json_encode($insights);
$conn->close();
?>
