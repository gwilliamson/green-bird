<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Redirecting to Login...</title>
    <script>
        document.addEventListener("DOMContentLoaded", function () {
            window.location.href = "${COGNITO_LOGIN_URL}";
        });
    </script>
</head>
<body>
    <main>
        <p>Redirecting to login...</p>
    </main>
</body>
</html>
