output "api_endpoint" {
  value = "${aws_api_gateway_stage.svm.invoke_url}/vend"
}

output "api_id" {
  value = aws_api_gateway_rest_api.svm.id
}
