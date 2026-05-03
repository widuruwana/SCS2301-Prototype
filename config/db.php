<?php
define('DB_HOST', 'localhost');
define('DB_NAME', 'scs2301_prototype');
define('DB_USER', 'scs2301_user');
define('DB_PASS', 'scs2301_pass');
define('DB_CHARSET', 'utf8mb4');

try {
	$pdo = new PDO(
		'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=' . DB_CHARSET,
		DB_USER,
		DB_PASS,
		[
			/*
			  Any failed query throws a catchable exception instead of
			  silently returning false.
			 */
			PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
			
			/*
			  Query results comes back as named arrays like $row['email']
			  instead of indexed $row[0]. Adds readability
			 */
			PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,

			/*
			  Force real prepared statements at the driver level, not PHP emulating
			  them. 
			 */
			PDO::ATTR_EMULATE_PREPARES => false,
		]
	);
} catch (PDOException $e) {
	error_log($e->getMessage());
	die('Database Connection Failed!. Check logs.');
}


?>
