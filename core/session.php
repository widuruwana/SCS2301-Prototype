<?php
if (session_status() === PHP_SESSION_NONE) {
	session_start();
}

// convenience accessor used across every file
// $_USER['id'], $_USER['role'], $_USER['email']
$_USER = $_SESSION['user'] ?? null;

function is_logged_in(): bool {
	return isset($_SESSION['user']);
}

function current_user(): ?array {
	return $_SESSION['user'] ?? null;
}

function login_user(array $user): void {
    	session_regenerate_id(true);
	$_SESSION['user'] = [
		'id'    => $user['id'],
		'email' => $user['email'],
		'role'  => $user['role'],
	];
}

function logout_user(): void {
    	$_SESSION = [];
    	session_destroy();
}
