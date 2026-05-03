<?php
require_once __DIR__ . '/../core/session.php';
require_once __DIR__ . '/../core/helpers.php';
require_once __DIR__ . '/../config/db.php';

// already logged in — redirect by role
if (is_logged_in()) {
    redirect('/SCS2301-Prototype/index.php');
}

$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email    = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';

    if ($email && $password) {
        $stmt = $pdo->prepare('SELECT id, email, password_hash, role FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if ($user && password_verify($password, $user['password_hash'])) {
            login_user($user);
            redirect('/SCS2301-Prototype/index.php');
        }
    }

    $error = 'Invalid email or password.';
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Login — SCS2301</title>
    <link rel="stylesheet" href="/SCS2301-Prototype/public/style.css">
</head>
<body>
<div class="auth-box">
    <h1>Scholarship Portal</h1>
    <h2>Sign in</h2>

    <?php if ($error): ?>
        <p class="error"><?= sanitize($error) ?></p>
    <?php endif; ?>

    <form method="POST">
        <label>Email
            <input type="email" name="email" required autofocus
                   value="<?= sanitize($_POST['email'] ?? '') ?>">
        </label>
        <label>Password
            <input type="password" name="password" required>
        </label>
        <button type="submit">Sign in</button>
    </form>

    <p>No account? <a href="/SCS2301-Prototype/auth/register.php">Register as student</a></p>
</div>
</body>
</html>