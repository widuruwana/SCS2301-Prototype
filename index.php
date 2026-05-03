<?php
require_once __DIR__ . '/core/session.php';
require_once __DIR__ . '/core/helpers.php';

if (!is_logged_in()) {
    redirect('/SCS2301-Prototype/auth/login.php');
}

switch ($_USER['role']) {
    case 'admin':
        redirect('/SCS2301-Prototype/scholarships/index.php');
        break;
    case 'reviewer':
        redirect('/SCS2301-Prototype/review/index.php');
        break;
    case 'student':
        redirect('/SCS2301-Prototype/applicant/dashboard.php');
        break;
    default:
        logout_user();
        redirect('/SCS2301-Prototype/auth/login.php');
}