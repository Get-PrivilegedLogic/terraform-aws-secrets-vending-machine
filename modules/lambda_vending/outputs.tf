output "lambda_invoke_arn" { value = aws_lambda_function.vending_machine.invoke_arn }
output "lambda_arn"        { value = aws_lambda_function.vending_machine.arn }
output "lambda_name"       { value = aws_lambda_function.vending_machine.function_name }
