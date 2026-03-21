/**
 * AIStepHandlerHttp
 *
 * Makes an HTTP callout for HTTP_CALLOUT step type.
 * Configuration stored in step.Condition__c as JSON:
 * {
 *   "namedCredential": "My_NC",    // required — Named Credential API name
 *   "path": "/api/endpoint",       // required
 *   "method": "POST",              // default GET
 *   "body": "{...}",               // optional, supports {context_key} interpolation
 *   "timeoutMs": 10000             // default 10000
 * }
 *
 * Security: namedCredential name sanitised; no raw endpoint URLs allowed.
 */
public with sharing class AIStepHandlerHttp implements AIStepHandler {

    public AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId) {
        Datetime start = Datetime.now();

        Map<String, Object> config;
        try {
            config = (Map<String, Object>) AISecurityUtil.safeDeserialise(step.Condition__c);
        } catch (Exception e) {
            return AIStepResult.fail('HTTP step config (Condition__c) is not valid JSON: ' + e.getMessage());
        }

        String namedCred = (String) config.get('namedCredential');
        String path      = (String) config.get('path');
        String method    = config.containsKey('method') ? (String) config.get('method') : 'GET';
        String body      = (String) config.get('body');
        Integer timeout  = config.containsKey('timeoutMs') ? ((Decimal) config.get('timeoutMs')).intValue() : 10000;

        if (String.isBlank(namedCred) || String.isBlank(path)) {
            return AIStepResult.fail('HTTP step requires namedCredential and path in Condition__c JSON.');
        }

        try {
            AISecurityUtil.sanitiseNamedCredentialName(namedCred);
        } catch (Exception e) {
            return AIStepResult.fail('Invalid namedCredential name: ' + e.getMessage());
        }

        // Interpolate {context_key} placeholders in body
        if (String.isNotBlank(body)) {
            for (String key : context.keySet()) {
                body = body.replace('{' + key + '}', String.valueOf(context.get(key)));
            }
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + namedCred + path);
        req.setMethod(method.toUpperCase());
        req.setTimeout(timeout);
        if (String.isNotBlank(body)) {
            req.setBody(body);
            req.setHeader('Content-Type', 'application/json');
        }

        try {
            HttpResponse resp = new Http().send(req);
            Integer durationMs = (Datetime.now().getTime() - start.getTime()).intValue();

            if (resp.getStatusCode() >= 200 && resp.getStatusCode() < 300) {
                AIStepResult result = AIStepResult.ok(resp.getBody().left(131072));
                result.durationMs = durationMs;
                return result;
            } else {
                return AIStepResult.fail('HTTP ' + resp.getStatusCode() + ': ' + resp.getBody().left(1000));
            }
        } catch (Exception e) {
            return AIStepResult.fail('HTTP callout exception: ' + e.getMessage());
        }
    }
}
