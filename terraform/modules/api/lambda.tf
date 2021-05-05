###################################
# events-api-authorizer lambda function
###################################

resource "aws_iam_role" "events-api-authorizer-invocation-role" {
  name = "${var.prefix}-events-api-authorizer-invocation-role-${var.stage}"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "events-api-authorizer-invocation-policy" {
  name = "${var.prefix}-events-api-authorizer-invocation-policy-${var.stage}"
  role = aws_iam_role.events-api-authorizer-invocation-role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.events-api-authorizer.arn}"
    }
  ]
}
EOF
}


# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "events-api-authorizer-role" {
  name = "${var.prefix}-events-api-authorizer-role-${var.stage}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "events-api-authorizer-policy" {
    name        = "${var.prefix}-events-api-authorizer-policy-${var.stage}"
    description = ""
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "events-api-authorizer-attach" {
    role       = aws_iam_role.events-api-authorizer-role.name
    policy_arn = aws_iam_policy.events-api-authorizer-policy.arn
}

resource "aws_lambda_function" "events-api-authorizer" {
  function_name = "${var.prefix}-events-api-authorizer-${var.stage}"

  # The zip containing the lambda function
  filename    = "../../../lambda/dist/functions/api-authorizer.zip"
  source_code_hash = filebase64sha256("../../../lambda/dist/functions/api-authorizer.zip")

  # "index" is the filename within the zip file (index.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "index.handler"
  runtime = var.runtime
  timeout = 10

  role = aws_iam_role.events-api-authorizer-role.arn

  // The run time environment dependencies (package.json & node_modules)
  layers = [aws_lambda_layer_version.lambda_layer.id]

  environment {
    variables = {
      region =  var.region,
      userpool_id = var.cognito_user_pool_id
    }
  }
}

###################################
# get-events lambda function
###################################

resource "aws_lambda_function" "get-events" {
  function_name = "${var.prefix}-get-events-${var.stage}"

  # The zip containing the lambda function
  filename    = "../../../lambda/dist/functions/get.zip"
  source_code_hash = filebase64sha256("../../../lambda/dist/functions/get.zip")

  # "index" is the filename within the zip file (index.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "index.handler"
  runtime = var.runtime
  timeout = 10

  role = aws_iam_role.get-events-role.arn

  // The run time environment dependencies (package.json & node_modules)
  layers = [aws_lambda_layer_version.lambda_layer.id]

  environment {
    variables = {
      region =  var.region,
      table = aws_dynamodb_table.events_table.id
    }
  }
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "get-events-role" {
  name = "${var.prefix}-get-events-role-${var.stage}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "get-events-policy" {
    name        = "${var.prefix}-get-events-policy-${var.stage}"
    description = ""
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    },
    {
      "Action": [
        "dynamodb:Scan"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${aws_dynamodb_table.events_table.id}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "get-events-attach" {
    role       = aws_iam_role.get-events-role.name
    policy_arn = aws_iam_policy.get-events-policy.arn
}

resource "aws_lambda_permission" "get-events-apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get-events.arn
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.events-api.execution_arn}/*/*"
}

###################################
# create-event function
###################################

resource "aws_lambda_function" "create-event" {
  function_name = "${var.prefix}-create-event-${var.stage}"

  # The zip containing the lambda function
  filename    = "../../../lambda/dist/functions/create.zip"
  source_code_hash = filebase64sha256("../../../lambda/dist/functions/create.zip")

  # "index" is the filename within the zip file (index.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "index.handler"
  runtime = var.runtime
  timeout = 10

  role = aws_iam_role.create-event-role.arn

  // The run time environment dependencies (package.json & node_modules)
  layers = [aws_lambda_layer_version.lambda_layer.id]

  environment {
    variables = {
      region =  var.region,
      table = aws_dynamodb_table.events_table.id
    }
  }
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "create-event-role" {
  name = "${var.prefix}-create-event-role-${var.stage}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "create-event-policy" {
    name        = "${var.prefix}-create-event-policy-${var.stage}"
    description = ""
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    },
    {
      "Action": [
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${aws_dynamodb_table.events_table.id}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "create-event-attach" {
    role       = aws_iam_role.create-event-role.name
    policy_arn = aws_iam_policy.create-event-policy.arn
}

resource "aws_lambda_permission" "create-event-apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create-event.arn
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.events-api.execution_arn}/*/*"
}


###################################
# get-event-details function
###################################

resource "aws_lambda_function" "get-event-details" {
  function_name = "${var.prefix}-get-event-details-${var.stage}"

  # The zip containing the lambda function
  filename    = "../../../lambda/dist/functions/get-item.zip"
  source_code_hash = filebase64sha256("../../../lambda/dist/functions/get-item.zip")

  # "index" is the filename within the zip file (index.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "index.handler"
  runtime = var.runtime
  timeout = 10

  role = aws_iam_role.get-event-details-role.arn

  // The run time environment dependencies (package.json & node_modules)
  layers = [aws_lambda_layer_version.lambda_layer.id]

  environment {
    variables = {
      region =  var.region,
      table = aws_dynamodb_table.events_table.id
    }
  }
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "get-event-details-role" {
  name = "${var.prefix}-get-event-details-role-${var.stage}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "get-event-details-policy" {
    name        = "${var.prefix}-get-event-details-policy-${var.stage}"
    description = ""
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    },
    {
      "Action": [
        "dynamodb:GetItem"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${aws_dynamodb_table.events_table.id}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "get-event-details-attach" {
    role       = aws_iam_role.get-event-details-role.name
    policy_arn = aws_iam_policy.get-event-details-policy.arn
}

resource "aws_lambda_permission" "get-event-details-apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get-event-details.arn
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.events-api.execution_arn}/*/*"
}


###################################
# delete-event function
###################################

resource "aws_lambda_function" "delete-event" {
  function_name = "${var.prefix}-delete-event-${var.stage}"

  # The zip containing the lambda function
  filename    = "../../../lambda/dist/functions/delete.zip"
  source_code_hash = filebase64sha256("../../../lambda/dist/functions/delete.zip")

  # "index" is the filename within the zip file (index.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "index.handler"
  runtime = var.runtime
  timeout = 10

  role = aws_iam_role.delete-event-role.arn

  // The run time environment dependencies (package.json & node_modules)
  layers = [aws_lambda_layer_version.lambda_layer.id]

  environment {
    variables = {
      region =  var.region,
      table = aws_dynamodb_table.events_table.id
    }
  }
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "delete-event-role" {
  name = "${var.prefix}-delete-event-role-${var.stage}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "delete-event-policy" {
    name        = "${var.prefix}-delete-event-policy-${var.stage}"
    description = ""
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    },
    {
      "Action": [
        "dynamodb:DeleteItem"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${aws_dynamodb_table.events_table.id}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "delete-event-attach" {
    role       = aws_iam_role.delete-event-role.name
    policy_arn = aws_iam_policy.delete-event-policy.arn
}

resource "aws_lambda_permission" "delete-event-apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete-event.arn
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.events-api.execution_arn}/*/*"
}

###################################
# update-event function
###################################

resource "aws_lambda_function" "update-event" {
  function_name = "${var.prefix}-update-event-${var.stage}"

  # The zip containing the lambda function
  filename    = "../../../lambda/dist/functions/update.zip"
  source_code_hash = filebase64sha256("../../../lambda/dist/functions/update.zip")

  # "index" is the filename within the zip file (index.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "index.handler"
  runtime = var.runtime
  timeout = 10

  role = aws_iam_role.update-event-role.arn

  // The run time environment dependencies (package.json & node_modules)
  layers = [aws_lambda_layer_version.lambda_layer.id]

  environment {
    variables = {
      region =  var.region,
      table = aws_dynamodb_table.events_table.id
    }
  }
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "update-event-role" {
  name = "${var.prefix}-update-event-role-${var.stage}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "update-event-policy" {
    name        = "${var.prefix}-update-event-policy-${var.stage}"
    description = ""
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    },
    {
      "Action": [
        "dynamodb:UpdateItem"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${aws_dynamodb_table.events_table.id}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "update-event-attach" {
    role       = aws_iam_role.update-event-role.name
    policy_arn = aws_iam_policy.update-event-policy.arn
}

resource "aws_lambda_permission" "update-event-apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update-event.arn
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.events-api.execution_arn}/*/*"
}

###################################
# get-my-events function
###################################

resource "aws_lambda_function" "get-my-events" {
  function_name = "${var.prefix}-get-my-events-${var.stage}"

  # The zip containing the lambda function
  filename         = "../../../lambda/dist/functions/get-my.zip"
  source_code_hash = filebase64sha256("../../../lambda/dist/functions/get-my.zip")

  # "index" is the filename within the zip file (index.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "index.handler"
  runtime = var.runtime
  timeout = 10

  role = aws_iam_role.get-my-events-role.arn

  // The run time environment dependencies (package.json & node_modules)
  layers = [aws_lambda_layer_version.lambda_layer.id]

  environment {
    variables = {
      region = var.region,
      table  = aws_dynamodb_table.events_table.id
    }
  }
}

# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "get-my-events-role" {
  name = "${var.prefix}-get-my-events-role-${var.stage}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "get-my-events-policy" {
  name        = "${var.prefix}-get-my-events-policy-${var.stage}"
  description = ""
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    },
    {
      "Action": [
        "dynamodb:Query"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${aws_dynamodb_table.events_table.id}"
    },
    {
      "Action": [
        "dynamodb:Query"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${aws_dynamodb_table.events_table.id}/index/*"
    }

  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "get-my-events-attach" {
  role       = aws_iam_role.get-my-events-role.name
  policy_arn = aws_iam_policy.get-my-events-policy.arn
}

resource "aws_lambda_permission" "get-my-events-apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get-my-events.arn
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.events-api.execution_arn}/*/*"
}
