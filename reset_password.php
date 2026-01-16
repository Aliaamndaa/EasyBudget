<?php
include 'db_config.php';

$email = $_POST['email'];
$new_password = password_hash($_POST['new_password'], PASSWORD_DEFAULT);

$query = "SELECT * FROM userdata WHERE email = '$email'";
$result = mysqli_query($conn, $query);

if (mysqli_num_rows($result) > 0) {
    $update_query = "UPDATE userdata SET password = '$new_password' WHERE email = '$email'";
    if (mysqli_query($conn, $update_query)) {
        echo json_encode(["status" => "success", "message" => "Password reset successfully."]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to update password."]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Email not found."]);
}

mysqli_close($conn);
?>
