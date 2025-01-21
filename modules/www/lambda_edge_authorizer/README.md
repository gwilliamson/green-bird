# Lambda Edge Authorizer

The idea here was to protect the app assets to prevent download by anyone not authenticated.

I still like the idea but ran into some issues, like

- Lambda@Edge has a 3-second timeout by default, and offers a max of 5 seconds. This should be enough to do some JWT cookie checking. But tripped me up because there's no indication in CloudWatch logs that the timeout was reached.
- I was having trouble getting the Python cryptography package to work.

So it is not currently in use -- requests for app assets are delivered without authentication. 