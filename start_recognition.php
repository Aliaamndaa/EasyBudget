<?php
// Get the subject_id from the GET parameter and sanitize it
$subject_id = isset($_GET['subject_id']) ? intval($_GET['subject_id']) : 1; // Default subject_id = 1

// Define the path to your Python script
$python_script_path = 'C:\\Program Files\\Python313\\app.py'; // Update with the actual path

// Make sure the Python script exists
if (!file_exists($python_script_path)) {
    echo json_encode(["success" => false, "message" => "Python script not found."]);
    exit;
}

// Construct the shell command to execute the Python script
$command = escapeshellcmd("python3 $python_script_path $subject_id");

// Execute the command and capture the output
$output = shell_exec($command);

// Check if the command executed successfully
if ($output) {
    echo json_encode(["success" => true, "message" => "Recognition started successfully."]);
} else {
    echo json_encode(["success" => false, "message" => "Failed to start recognition."]);
}
?>
