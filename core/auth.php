<?php
require_once __DIR__ . '/../core/session.php';

// usage: require_role('admin')
// usage: require_role(['admin', 'reviewer'])
function require_role(string|array $roles): void {
    if (!is_logged_in()) {
        header('Location: /SCS2301-Prototype/auth/login.php');
        exit;
    }

    $roles = (array) $roles;

    if (!in_array($_SESSION['user']['role'], $roles, true)) {
        http_response_code(403);
        die('Access denied.');
    }
}