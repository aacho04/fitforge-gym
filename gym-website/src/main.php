
<?php
function calculate($num1, $num2, $operation) {
    switch ($operation) {
        case "add":
            return $num1 + $num2;

        case "sub":
            return $num1 - $num2;

        case "mul":
            return $num1 * $num2;

        case "div":
            if ($num2 == 0) {
                return "Cannot divide by zero";
            }
            return $num1 / $num2;

        default:
            return "Invalid operation";
    }
}

$options = [
    'uri' => 'http://localhost/soap_calculator/'
];

$server = new SoapServer(null, $options);
$server->addFunction("calculate");
$server->handle();
?>
