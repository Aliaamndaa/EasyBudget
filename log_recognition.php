<?php
$subject_id = isset($_GET['subject_id']) ? intval($_GET['subject_id']) : 1; // Default subject_id = 1
$command = escapeshellcmd("python3 /path/to/your/script.py $subject_id");
$output = shell_exec($command);

if ($output) {
    echo json_encode(["success" => true, "message" => "Recognition started successfully."]);
} else {
    echo json_encode(["success" => false, "message" => "Failed to start recognition."]);
}
?>
