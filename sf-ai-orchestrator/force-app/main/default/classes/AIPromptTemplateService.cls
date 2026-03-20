/**
 * AIPromptTemplateService
 *
 * Resolves {{Object.Field}} variable interpolation in prompt templates.
 *
 * Security:
 *  - Field names validated via AISecurityUtil (allowlist pattern)
 *  - FLS checked before reading any field value
 *  - Object names validated against org describe (no arbitrary SOQL injection)
 *  - Max 50 variables per prompt (prevents DoS via excessive SOQL)
 *
 * Example template:
 *   "Analyse this lead: {{Lead.Name}}, Company: {{Lead.Company}}, Email: {{Lead.Email}}"
 *
 * @author  AI Orchestration Package
 * @version 1.0
 */
public with sharing class AIPromptTemplateService {

    private static final Integer MAX_VARIABLES = 50;
    private static final Pattern VARIABLE_PATTERN = Pattern.compile('\\{\\{([A-Za-z][A-Za-z0-9_]*)(\\.([A-Za-z][A-Za-z0-9_]*(__c|__r)?))\\}\\}');

    public class TemplateException extends Exception {}

    /**
     * Resolves a prompt template against a Salesforce record.
     *
     * @param template     Raw prompt template with {{Object.Field}} tokens
     * @param recordId     The record to read field values from
     * @param objectName   API name of the SObject type
     * @return             Resolved prompt string
     */
    public static String resolve(String template, Id recordId, String objectName) {
        if (String.isBlank(template)) {
            throw new TemplateException('Template cannot be blank');
        }
        AISecurityUtil.sanitiseObjectName(objectName);

        // Extract variable tokens
        List<String> fieldNames = extractFieldNames(template, objectName);

        if (fieldNames.isEmpty()) {
            // No variables — return as-is (after basic sanitisation)
            return AISecurityUtil.sanitisePrompt(template);
        }

        if (fieldNames.size() > MAX_VARIABLES) {
            throw new TemplateException('Template exceeds maximum of ' + MAX_VARIABLES + ' variables');
        }

        // Validate CRUD + FLS
        SObjectType objType = Schema.getGlobalDescribe().get(objectName.toLowerCase());
        if (objType == null) {
            throw new TemplateException('Unknown object: ' + objectName);
        }
        AISecurityUtil.assertReadable(objType);
        AISecurityUtil.assertFieldsReadable(objType, fieldNames);

        // Query record with only requested fields
        String soql = buildSOQL(objectName, fieldNames, recordId);
        List<SObject> records;
        try {
            records = Database.query(soql);
        } catch (QueryException qe) {
            throw new TemplateException('Failed to query record: ' + qe.getMessage());
        }

        if (records.isEmpty()) {
            throw new TemplateException('Record not found: ' + recordId);
        }

        SObject record = records[0];
        return interpolate(template, record, objectName);
    }

    /**
     * Resolves a template using a pre-built map of variable values.
     * Useful when the record has already been queried.
     *
     * @param template    Raw prompt template
     * @param variables   Map of 'Object.Field' -> value
     */
    public static String resolveWithMap(String template, Map<String, String> variables) {
        if (String.isBlank(template)) {
            throw new TemplateException('Template cannot be blank');
        }
        String resolved = template;
        for (String key : variables.keySet()) {
            String value = variables.get(key) != null ? variables.get(key) : '';
            resolved = resolved.replace('{{' + key + '}}', value);
        }
        return AISecurityUtil.sanitisePrompt(resolved);
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────

    private static List<String> extractFieldNames(String template, String objectName) {
        List<String> fieldNames = new List<String>();
        Set<String>  seen       = new Set<String>();

        Matcher m = VARIABLE_PATTERN.matcher(template);
        while (m.find()) {
            String tokenObject = m.group(1); // Object name part
            String tokenField  = m.group(3); // Field name part
            if (tokenObject.equalsIgnoreCase(objectName) && !seen.contains(tokenField)) {
                seen.add(tokenField);
                fieldNames.add(tokenField);
            }
        }
        return fieldNames;
    }

    private static String buildSOQL(String objectName, List<String> fieldNames, Id recordId) {
        // Id field always included
        Set<String> fields = new Set<String>{'Id'};
        fields.addAll(fieldNames);
        String fieldList = String.join(new List<String>(fields), ', ');
        // Safe: objectName validated by sanitiseObjectName, fieldNames validated by FLS check
        // recordId is a typed Id — bind variable prevents injection
        return 'SELECT ' + fieldList + ' FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1';
    }

    private static String interpolate(String template, SObject record, String objectName) {
        Matcher m = VARIABLE_PATTERN.matcher(template);
        String  resolved = template;

        while (m.find()) {
            String tokenObject = m.group(1);
            String tokenField  = m.group(3);
            String placeholder = '{{' + tokenObject + '.' + tokenField + '}}';

            if (tokenObject.equalsIgnoreCase(objectName)) {
                Object rawValue = record.get(tokenField);
                String strValue = rawValue != null ? String.valueOf(rawValue) : '';
                // Sanitise value to prevent prompt injection
                strValue = strValue.replace('{{', '{ {').replace('}}', '} }');
                resolved = resolved.replace(placeholder, strValue);
            }
        }
        return resolved;
    }
}
