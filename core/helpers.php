<?php
function sanitize(string $input): string {
    return htmlspecialchars(trim($input), ENT_QUOTES, 'UTF-8');
}

function redirect(string $path): void {
    header('Location: ' . $path);
    exit;
}

function flash(string $message, string $type = 'info'): void {
    $_SESSION['flash'] = ['message' => $message, 'type' => $type];
}

function get_flash(): ?array {
    if (!isset($_SESSION['flash'])) return null;
    $flash = $_SESSION['flash'];
    unset($_SESSION['flash']);
    return $flash;
}

function format_date(string $date): string {
    return date('d M Y', strtotime($date));
}

function format_money(float $amount): string {
    return 'Rs. ' . number_format($amount, 2);
}

function time_elapsed(string $datetime): string {
    $diff = time() - strtotime($datetime);
    if ($diff < 3600)   return floor($diff / 60) . ' minutes ago';
    if ($diff < 86400)  return floor($diff / 3600) . ' hours ago';
    return floor($diff / 86400) . ' days ago';
}