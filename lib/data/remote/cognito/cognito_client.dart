import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:sigv4/sigv4.dart';

Future<bool> attachPolicy(
    {required String accessKey,
    required String secretKey,
    required String sessionToken,
    required String identityId,
    required String iotApiUrl,
    required String region,
    required String policyName}) async {
  final sigv4Client = Sigv4Client(
      keyId: accessKey,
      accessKey: secretKey,
      sessionToken: sessionToken,
      region: region,
      serviceName: 'execute-api');

  final body = json.encode({'target': identityId});

  final request =
      sigv4Client.request('$iotApiUrl/$policyName', method: 'PUT', body: body);

  var result = await put(request.url, headers: request.headers, body: body);

  if (result.statusCode != 200) {
    print('Error attaching IoT Policy ${result.body}');
  }

  return result.statusCode == 200;
}

Future<String> getWebSocketURL(
    {required String accessKey,
    required String secretKey,
    required String sessionToken,
    required String region,
    required String scheme,
    required String endpoint,
    required String urlPath}) async {
  const serviceName = 'iotdevicegateway';
  const awsS4Request = 'aws4_request';
  const aws4HmacSha256 = 'AWS4-HMAC-SHA256';
  var now = Sigv4.generateDatetime();

  var creds = [
    accessKey,
    now.substring(0, 8),
    region,
    serviceName,
    awsS4Request,
  ];

  var queryParams = {
    'X-Amz-Algorithm': aws4HmacSha256,
    'X-Amz-Credential': creds.join('/'),
    'X-Amz-Date': now,
    'X-Amz-SignedHeaders': 'host',
  };

  var canonicalQueryString = Sigv4.buildCanonicalQueryString(queryParams);

  var request = Sigv4.buildCanonicalRequest(
    'GET',
    urlPath,
    queryParams,
    {'host': endpoint},
    '',
  );

  var hashedCanonicalRequest = Sigv4.hashPayload(request);
  var stringToSign = Sigv4.buildStringToSign(
    now,
    Sigv4.buildCredentialScope(now, region, serviceName),
    hashedCanonicalRequest,
  );

  var signingKey = Sigv4.calculateSigningKey(
    secretKey,
    now,
    region,
    serviceName,
  );

  var signature = Sigv4.calculateSignature(signingKey, stringToSign);

  var finalParams =
      '$canonicalQueryString&X-Amz-Signature=$signature&X-Amz-Security-Token=${Uri.encodeComponent(sessionToken)}';

  return '$scheme$endpoint$urlPath?$finalParams';
}
