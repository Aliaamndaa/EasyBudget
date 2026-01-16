<?php
// Sambungan ke pangkalan data
$host = 'localhost';
$db = 'smartattendance';
$user = 'root';
$pass = '';
$conn = new mysqli($host, $user, $pass, $db);

// Periksa sambungan
if ($conn->connect_error) {
    die(json_encode(['success' => false, 'message' => 'Database connection failed: ' . $conn->connect_error]));
}

// Terima parameter POST
$year = $_POST['year'] ?? '';
$programme = $_POST['programme'] ?? '';
$semester = $_POST['semester'] ?? '';
$class = $_POST['class'] ?? '';

if (empty($year) || empty($programme) || empty($semester) || empty($class)) {
    echo json_encode(['success' => false, 'message' => 'Year, Programme, Semester, and Class are required.']);
    exit;
}

// SQL query to fetch subjects based on year, programme, semester, and class (class = section in the database)
$sql = "SELECT t.subject, l.LectName 
        FROM timetablelect t
        INNER JOIN lecturer l ON t.Staff_ID = l.Staff_ID
        WHERE t.year = ? AND t.programme = ? AND t.semester = ? AND t.class = ?";
$stmt = $conn->prepare($sql);
if ($stmt === false) {
    echo json_encode(['success' => false, 'message' => 'Failed to prepare SQL query: ' . $conn->error]);
    exit;
}

$stmt->bind_param("ssss", $year, $programme, $semester, $class);

if ($stmt->execute()) {
    $result = $stmt->get_result();
    $data = [];

    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }

    if (empty($data)) {
        echo json_encode(['success' => false, 'message' => 'No subjects found for the given criteria.']);
    } else {
        echo json_encode(['success' => true, 'data' => $data]);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Query execution failed: ' . $stmt->error]);
}

$stmt->close();
$conn->close();
?>