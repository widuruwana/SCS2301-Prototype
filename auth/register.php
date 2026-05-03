<?php
require_once __DIR__ . '/../core/session.php';
require_once __DIR__ . '/../core/helpers.php';
require_once __DIR__ . '/../config/db.php';

if (is_logged_in()) {
    redirect('/SCS2301-Prototype/index.php');
}

$error  = null;
$fields = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $fields = [
        'email'        => trim($_POST['email']        ?? ''),
        'password'     => $_POST['password']          ?? '',
        'index_number' => trim($_POST['index_number'] ?? ''),
        'full_name'    => trim($_POST['full_name']    ?? ''),
        'faculty'      => trim($_POST['faculty']      ?? ''),
        'department'   => trim($_POST['department']   ?? ''),
        'year_of_study'=> trim($_POST['year_of_study']?? ''),
        'gpa'          => trim($_POST['gpa']          ?? ''),
        'address'      => trim($_POST['address']      ?? ''),
    ];

    // basic validation
    if (!filter_var($fields['email'], FILTER_VALIDATE_EMAIL)) {
        $error = 'Invalid email address.';
    } elseif (strlen($fields['password']) < 8) {
        $error = 'Password must be at least 8 characters.';
    } elseif (!$fields['index_number'] || !$fields['full_name']) {
        $error = 'Index number and full name are required.';
    } else {
        try {
            $pdo->beginTransaction();

            // insert user
            $stmt = $pdo->prepare(
                'INSERT INTO users (email, password_hash, role)
                 VALUES (?, ?, "student")'
            );
            $stmt->execute([
                $fields['email'],
                password_hash($fields['password'], PASSWORD_BCRYPT)
            ]);
            $user_id = $pdo->lastInsertId();

            // insert student profile
            // in real system these fields come from faculty DB
            // here student enters them at registration (prototype only)
            $stmt = $pdo->prepare(
                'INSERT INTO student_profiles
                    (user_id, index_number, full_name, faculty,
                     department, year_of_study, gpa, address)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
            );
            $stmt->execute([
                $user_id,
                $fields['index_number'],
                $fields['full_name'],
                $fields['faculty'],
                $fields['department'],
                $fields['year_of_study'] ?: null,
                $fields['gpa']           ?: null,
                $fields['address'],
            ]);

            $pdo->commit();

            flash('Registration successful. Please sign in.', 'success');
            redirect('/SCS2301-Prototype/auth/login.php');

        } catch (PDOException $e) {
            $pdo->rollBack();
            if ($e->getCode() === '23000') {
                $error = 'Email or index number already registered.';
            } else {
                $error = 'Registration failed. Please try again.';
                error_log($e->getMessage());
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Register — SCS2301</title>
    <link rel="stylesheet" href="/SCS2301-Prototype/public/style.css">
</head>
<body>
<div class="auth-box">
    <h1>Scholarship Portal</h1>
    <h2>Student registration</h2>
    <p class="note">In the live system your details are pulled automatically from the faculty registry. For this prototype please enter them manually.</p>

    <?php if ($error): ?>
        <p class="error"><?= sanitize($error) ?></p>
    <?php endif; ?>

    <form method="POST">
        <label>Email
            <input type="email" name="email" required
                   value="<?= sanitize($fields['email'] ?? '') ?>">
        </label>
        <label>Password
            <input type="password" name="password" required>
        </label>
        <label>Index number
            <input type="text" name="index_number" required
                   value="<?= sanitize($fields['index_number'] ?? '') ?>">
        </label>
        <label>Full name
            <input type="text" name="full_name" required
                   value="<?= sanitize($fields['full_name'] ?? '') ?>">
        </label>
        <label>Faculty
            <input type="text" name="faculty"
                   value="<?= sanitize($fields['faculty'] ?? '') ?>">
        </label>
        <label>Department
            <input type="text" name="department"
                   value="<?= sanitize($fields['department'] ?? '') ?>">
        </label>
        <label>Year of study
            <input type="number" name="year_of_study" min="1" max="6"
                   value="<?= sanitize($fields['year_of_study'] ?? '') ?>">
        </label>
        <label>GPA
            <input type="number" name="gpa" step="0.01" min="0" max="4"
                   value="<?= sanitize($fields['gpa'] ?? '') ?>">
        </label>
        <label>Address
            <textarea name="address"><?= sanitize($fields['address'] ?? '') ?></textarea>
        </label>
        <button type="submit">Create account</button>
    </form>

    <p>Already registered? <a href="/SCS2301-Prototype/auth/login.php">Sign in</a></p>
</div>
</body>
</html>