output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_execution.arn
}

output "vended_role_arn" {
  value = aws_iam_role.vended.arn
}

output "caller_role_arn" {
  value = aws_iam_role.caller.arn
}
