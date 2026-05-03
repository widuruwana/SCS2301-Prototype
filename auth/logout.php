<?php
require_once __DIR__ . '/../core/session.php';
require_once __DIR__ . '/../core/helpers.php';

logout_user();
flash('You have been signed out.', 'info');
redirect('/SCS2301-Prototype/auth/login.php');