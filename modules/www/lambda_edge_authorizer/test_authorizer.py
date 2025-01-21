import unittest
from unittest.mock import patch, MagicMock
import json

# Import your Lambda function
from authorizer import handler, verify_jwt, get_ssm_param, get_cognito_keys

class TestLambdaHandler(unittest.TestCase):

    @patch('authorizer.get_ssm_param')
    @patch('authorizer.get_cognito_keys')
    @patch('authorizer.verify_jwt')
    def test_protected_assets_with_valid_jwt(self, mock_verify_jwt, mock_get_cognito_keys, mock_get_ssm_param):
        # Mock the SSM parameter retrieval
        mock_get_ssm_param.side_effect = lambda name: {
            "/cognito/green_bird_region": "us-east-1",
            "/cognito/green_bird_user_pool_id": "mock_user_pool_id",
            "/cognito/green_bird_client_id": "mock_client_id"
        }[name]

        # Mock the Cognito keys and JWT verification
        mock_get_cognito_keys.return_value = {'mock_kid': 'mock_key'}
        mock_verify_jwt.return_value = {'sub': 'user_id'}

        # Mock the event with a request to /assets/
        event = {
            'Records': [{
                'cf': {
                    'request': {
                        'uri': '/assets/js/app.js',
                        'headers': {
                            'cookie': [{'value': 'id_token=mock_token; other_cookie=abc'}]
                        }
                    }
                }
            }]
        }

        context = {}

        response = handler(event, context)

        # Assert that the request proceeds
        self.assertEqual(response['uri'], '/assets/js/app.js')

    @patch('authorizer.get_ssm_param')
    @patch('authorizer.get_cognito_keys')
    @patch('authorizer.verify_jwt')
    def test_protected_assets_with_invalid_jwt(self, mock_verify_jwt, mock_get_cognito_keys, mock_get_ssm_param):
        # Mock the SSM parameter retrieval
        mock_get_ssm_param.side_effect = lambda name: {
            "/cognito/green_bird_region": "us-east-1",
            "/cognito/green_bird_user_pool_id": "mock_user_pool_id",
            "/cognito/green_bird_client_id": "mock_client_id"
        }[name]

        # Mock the Cognito keys and JWT verification to throw an exception
        mock_get_cognito_keys.return_value = {'mock_kid': 'mock_key'}
        mock_verify_jwt.side_effect = Exception('Invalid JWT')

        # Mock the event with a request to /assets/
        event = {
            'Records': [{
                'cf': {
                    'request': {
                        'uri': '/assets/js/app.js',
                        'headers': {
                            'cookie': [{'value': 'id_token=invalid_token; other_cookie=abc'}]
                        }
                    }
                }
            }]
        }

        context = {}

        response = handler(event, context)

        # Assert that the request is denied
        self.assertEqual(response['status'], '403')
        self.assertIn('Access denied. Invalid JWT.', response['body'])

    @patch('authorizer.get_ssm_param')
    @patch('authorizer.get_cognito_keys')
    def test_protected_assets_with_no_jwt(self, mock_get_cognito_keys, mock_get_ssm_param):
        # Mock the SSM parameter retrieval
        mock_get_ssm_param.side_effect = lambda name: {
            "/cognito/green_bird_region": "us-east-1",
            "/cognito/green_bird_user_pool_id": "mock_user_pool_id",
            "/cognito/green_bird_client_id": "mock_client_id"
        }[name]

        # Mock the Cognito keys
        mock_get_cognito_keys.return_value = {'mock_kid': 'mock_key'}

        # Mock the event with a request to /assets/
        event = {
            'Records': [{
                'cf': {
                    'request': {
                        'uri': '/assets/js/app.js',
                        'headers': {
                            'cookie': [{'value': 'other_cookie=abc'}]
                        }
                    }
                }
            }]
        }

        context = {}

        response = handler(event, context)

        # Assert that the request is denied
        self.assertEqual(response['status'], '403')
        self.assertIn('Access denied. JWT cookie not found.', response['body'])

if __name__ == '__main__':
    unittest.main()
