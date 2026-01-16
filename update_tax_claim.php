<?php
include 'db_config.php';

$claim_id = $_POST['claim_id'];
$amount = $_POST['amount'];
$category = $_POST['category'];
$description = $_POST['description'];
$claim_date = $_POST['date'];
$receipt_number = $_POST['receipt_number'];
$merchant_name = $_POST['merchant_name'];
$payment_method = $_POST['payment_method'];

$sql = "UPDATE tax_claims 
        SET amount=?, category=?, description=?, claim_date=?, receipt_number=?, merchant_name=?, payment_method=?
        WHERE claim_id=?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("sssssssi", $amount, $category, $description, $claim_date, $receipt_number, $merchant_name, $payment_method, $claim_id);

if ($stmt->execute()) {
    echo "success";
} else {
    echo "error";
}
?>
