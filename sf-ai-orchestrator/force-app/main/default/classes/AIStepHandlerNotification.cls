/**
 * AIStepHandlerNotification
 *
 * Sends an email notification via Messaging.sendEmail.
 * Config in step.Condition__c JSON:
 * {
 *   "toAddress": "admin@example.com",
 *   "subject": "Workflow complete: {step_1_output}",
 *   "body": "Result: {step_1_output}"
 * }
 * Supports {context_key} interpolation.
 *
 * Security: toAddress validated as email format.
 */
public with sharing class AIStepHandlerNotification implements AIStepHandler {

    public AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId) {
        Map<String, Object> config;
        try {
            config = (Map<String, Object>) AISecurityUtil.safeDeserialise(step.Condition__c);
        } catch (Exception e) {
            return AIStepResult.fail('NOTIFICATION config is not valid JSON: ' + e.getMessage());
        }

        String toAddress = (String) config.get('toAddress');
        String subject   = (String) config.get('subject');
        String body      = (String) config.get('body');

        if (String.isBlank(toAddress)) {
            return AIStepResult.fail('NOTIFICATION requires "toAddress" in Condition__c JSON.');
        }

        // Basic email format validation
        if (!toAddress.contains('@') || !toAddress.contains('.')) {
            return AIStepResult.fail('Invalid toAddress: ' + toAddress);
        }

        // Interpolate context values
        subject = interpolate(subject != null ? subject : 'AI Workflow Notification', context);
        body    = interpolate(body    != null ? body    : 'Workflow step completed.', context);

        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ toAddress });
            email.setSubject(subject.left(255));
            email.setPlainTextBody(body.left(32000));
            email.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
            return AIStepResult.ok('Notification sent to ' + toAddress);
        } catch (Exception e) {
            return AIStepResult.fail('Failed to send notification: ' + e.getMessage());
        }
    }

    private String interpolate(String template, Map<String, Object> context) {
        for (String key : context.keySet()) {
            template = template.replace('{' + key + '}', String.valueOf(context.get(key)));
        }
        return template;
    }
}
