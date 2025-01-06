import pytest
from unittest.mock import patch, MagicMock
import jwt
from authorizer import handler, generate_policy

# Constants for test
AWS_REGION = "us-west-1"
COGNITO_USER_POOL_ID = "us-west-1_EWeTP10YM"
COGNITO_CLIENT_ID = "vulo3vt2c6rum0e90re1f54l7"
JWKS_URL = f"https://cognito-idp.{AWS_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"

@pytest.fixture
def valid_event():
    """Fixture for a valid event with a token in the Cookie header."""
    return {
        "headers": {
            "cookie": "access_token=valid_token; refresh_token=another_token;"
        },
        "routeArn": "arn:aws:execute-api:region:account-id:api-id/stage-name/GET/protected"
    }

@pytest.fixture
def expired_event():
    """Fixture for an expired token event."""
    return {
        "headers": {
            "cookie": "access_token=expired_token; refresh_token=another_token;"
        },
        "routeArn": "arn:aws:execute-api:region:account-id:api-id/stage-name/GET/protected"
    }

@patch("authorizer.jwt.PyJWKClient")
def test_valid_token(mock_jwk_client, valid_event):
    """Test handler with a valid token."""
    # Mock PyJWKClient and signing key
    mock_jwk_client_instance = MagicMock()
    mock_signing_key = MagicMock()
    mock_signing_key.key = "mocked_key"
    mock_jwk_client_instance.get_signing_key_from_jwt.return_value = mock_signing_key
    mock_jwk_client.return_value = mock_jwk_client_instance

    # Mock jwt.decode to return decoded payload
    with patch("authorizer.jwt.decode") as mock_decode:
        mock_decode.return_value = {"sub": "user123"}

        response = handler(valid_event, None)

        # Assertions
        assert response["principalId"] == "user123"
        assert response["policyDocument"]["Statement"][0]["Effect"] == "Allow"
        mock_jwk_client_instance.get_signing_key_from_jwt.assert_called_once_with("valid_token")
        mock_decode.assert_called_once_with(
            "valid_token",
            "mocked_key",
            algorithms=["RS256"],
            audience=COGNITO_CLIENT_ID,
            options={"verify_exp": True}
        )

@patch("authorizer.jwt.PyJWKClient")
def test_expired_token(mock_jwk_client, expired_event):
    """Test handler with an expired token."""
    # Mock PyJWKClient and signing key
    mock_jwk_client_instance = MagicMock()
    mock_signing_key = MagicMock()
    mock_signing_key.key = "mocked_key"
    mock_jwk_client_instance.get_signing_key_from_jwt.return_value = mock_signing_key
    mock_jwk_client.return_value = mock_jwk_client_instance

    # Mock jwt.decode to raise ExpiredSignatureError
    with patch("authorizer.jwt.decode", side_effect=jwt.ExpiredSignatureError):
        response = handler(expired_event, None)

        # Assertions
        assert response["policyDocument"]["Statement"][0]["Effect"] == "Deny"
        assert response["policyDocument"]["Statement"][0]["Resource"] == expired_event["routeArn"]

@patch("authorizer.jwt.PyJWKClient")
def test_invalid_token(mock_jwk_client, valid_event):
    """Test handler with an invalid token."""
    # Mock PyJWKClient and signing key
    mock_jwk_client_instance = MagicMock()
    mock_signing_key = MagicMock()
    mock_signing_key.key = "mocked_key"
    mock_jwk_client_instance.get_signing_key_from_jwt.return_value = mock_signing_key
    mock_jwk_client.return_value = mock_jwk_client_instance

    # Mock jwt.decode to raise InvalidTokenError
    with patch("authorizer.jwt.decode", side_effect=jwt.InvalidTokenError("Invalid token")):
        response = handler(valid_event, None)

        # Assertions
        assert response["policyDocument"]["Statement"][0]["Effect"] == "Deny"
        assert response["policyDocument"]["Statement"][0]["Resource"] == valid_event["routeArn"]
