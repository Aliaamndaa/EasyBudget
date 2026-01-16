<?php
include 'db_connect.php';

$today = date('Y-m-d');
$tomorrow = date('Y-m-d', strtotime('+1 day'));

$sql = "SELECT * FROM bills WHERE due_date <= ? AND notified = FALSE";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $tomorrow);
$stmt->execute();
$result = $stmt->get_result();

$bills = [];
while ($row = $result->fetch_assoc()) {
    $bills[] = $row;

    // Here send FCM notification
    sendFCM($row['email'], $row['title'], $row['due_date']);
    
    // Mark as notified
    $update = $conn->prepare("UPDATE bills SET notified = TRUE WHERE id = ?");
    $update->bind_param("i", $row['id']);
    $update->execute();
}

function sendFCM($email, $title, $dueDate) {
    $fcmToken = getFcmTokenByEmail($email); // Implement this based on your user table

    $notification = [
        'to' => $fcmToken,
        'notification' => [
            'title' => 'Upcoming Bill Due',
            'body' => "$title is due on $dueDate",
            'sound' => 'default',
        ]
    ];

    $ch = curl_init("https://fcm.googleapis.com/fcm/send");
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: key=YOUR_FCM_SERVER_KEY",
        "Content-Type: application/json"
    ]);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($notification));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_exec($ch);
    curl_close($ch);
}
?>
