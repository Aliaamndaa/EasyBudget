<?php
include 'db_config.php';

$claim_id = $_POST['claim_id'];

$sql = "DELETE FROM tax_claims WHERE claim_id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $claim_id);

if ($stmt->execute()) {
    echo "success";
} else {
    echo "error";
}
?>
