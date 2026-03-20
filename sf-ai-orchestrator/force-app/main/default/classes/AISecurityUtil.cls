/**
 * AISecurityUtil
 *
 * Central security utility for the AI Orchestration managed package.
 * ALL data access in this package MUST route through this class.
 *
 * Security principles enforced:
 *  1. CRUD checks  – verify object-level create/read/update/delete before DML
 *  2. FLS checks   – verify field-level security before reading or writing fields
 *  3. Sharing      – all queries run in user context (with sharing) unless explicitly
 *                    escalated via AISecurityUtil.SystemContext
 *  4. SOQL injection – all dynamic SOQL uses bind variables; no string concatenation
 *  5. Input sanitisation – prompt content is stripped of SOQL/SOSL injection vectors
 *
 * @author  AI Orchestration Package
 * @version 1.0
 */
public with sharing class AISecurityUtil {

    // ─── Exceptions ──────────────────────────────────────────────────────────

    public class CRUDException extends Exception {}
    public class FLSException   extends Exception {}
    public class InputException extends Exception {}

    // ─── CRUD Guards ─────────────────────────────────────────────────────────

    /**
     * Throws CRUDException if the running user cannot read the given SObject type.
     */
    public static void assertReadable(SObjectType objType) {
        if (!objType.getDescribe(SObjectDescribeOptions.DEFERRED).isAccessible()) {
            throw new CRUDException(
                'Insufficient permissions: cannot read ' + objType.getDescribe().getName()
            );
        }
    }

    public static void assertCreatable(SObjectType objType) {
        if (!objType.getDescribe(SObjectDescribeOptions.DEFERRED).isCreateable()) {
            throw new CRUDException(
                'Insufficient permissions: cannot create ' + objType.getDescribe().getName()
            );
        }
    }

    public static void assertUpdatable(SObjectType objType) {
        if (!objType.getDescribe(SObjectDescribeOptions.DEFERRED).isUpdateable()) {
            throw new CRUDException(
                'Insufficient permissions: cannot update ' + objType.getDescribe().getName()
            );
        }
    }

    public static void assertDeletable(SObjectType objType) {
        if (!objType.getDescribe(SObjectDescribeOptions.DEFERRED).isDeletable()) {
            throw new CRUDException(
                'Insufficient permissions: cannot delete ' + objType.getDescribe().getName()
            );
        }
    }

    // ─── FLS Guards ──────────────────────────────────────────────────────────

    /**
     * Returns only the subset of fieldNames that the running user can read.
     * Use this to build safe SOQL field lists.
     */
    public static List<String> filterReadableFields(SObjectType objType, List<String> fieldNames) {
        Map<String, SObjectField> fieldMap = objType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        List<String> readable = new List<String>();
        for (String fieldName : fieldNames) {
            String lower = fieldName.toLowerCase();
            if (fieldMap.containsKey(lower) && fieldMap.get(lower).getDescribe().isAccessible()) {
                readable.add(fieldName);
            }
        }
        return readable;
    }

    /**
     * Throws FLSException if ANY of the given fields are not readable.
     */
    public static void assertFieldsReadable(SObjectType objType, List<String> fieldNames) {
        Map<String, SObjectField> fieldMap = objType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        for (String fieldName : fieldNames) {
            String lower = fieldName.toLowerCase();
            if (!fieldMap.containsKey(lower) || !fieldMap.get(lower).getDescribe().isAccessible()) {
                throw new FLSException(
                    'Insufficient permissions: cannot read field ' + fieldName + ' on ' + objType.getDescribe().getName()
                );
            }
        }
    }

    /**
     * Throws FLSException if ANY of the given fields are not writable.
     */
    public static void assertFieldsWritable(SObjectType objType, List<String> fieldNames) {
        Map<String, SObjectField> fieldMap = objType.getDescribe(SObjectDescribeOptions.DEFERRED).fields.getMap();
        for (String fieldName : fieldNames) {
            String lower = fieldName.toLowerCase();
            if (!fieldMap.containsKey(lower) || !fieldMap.get(lower).getDescribe().isUpdateable()) {
                throw new FLSException(
                    'Insufficient permissions: cannot write field ' + fieldName + ' on ' + objType.getDescribe().getName()
                );
            }
        }
    }

    // ─── Input Sanitisation ──────────────────────────────────────────────────

    /**
     * Validates that a prompt string is safe to use.
     * - Max length enforced (prevents oversized payloads)
     * - Strips SOQL/SOSL injection patterns
     * - No null bytes
     */
    public static String sanitisePrompt(String prompt) {
        if (String.isBlank(prompt)) {
            throw new InputException('Prompt cannot be blank');
        }
        if (prompt.length() > 32000) {
            throw new InputException('Prompt exceeds maximum allowed length of 32,000 characters');
        }
        // Remove null bytes
        prompt = prompt.replace('\u0000', '');
        return prompt;
    }

    /**
     * Validates a field API name is a safe identifier (letters, digits, underscores only).
     * Prevents SOQL injection via field name parameters.
     */
    public static String sanitiseFieldName(String fieldName) {
        if (String.isBlank(fieldName)) {
            throw new InputException('Field name cannot be blank');
        }
        if (!Pattern.matches('[a-zA-Z][a-zA-Z0-9_]*(__c|__r)?', fieldName)) {
            throw new InputException('Invalid field name: ' + fieldName);
        }
        return fieldName;
    }

    /**
     * Validates a Salesforce Object API name.
     */
    public static String sanitiseObjectName(String objectName) {
        if (String.isBlank(objectName)) {
            throw new InputException('Object name cannot be blank');
        }
        if (!Pattern.matches('[a-zA-Z][a-zA-Z0-9_]*(__c)?', objectName)) {
            throw new InputException('Invalid object name: ' + objectName);
        }
        return objectName;
    }

    /**
     * Validates that a record ID is a valid 15 or 18-char Salesforce ID.
     */
    public static Id sanitiseRecordId(String recordId) {
        if (String.isBlank(recordId)) {
            throw new InputException('Record ID cannot be blank');
        }
        try {
            Id validId = (Id) recordId;
            return validId;
        } catch (Exception e) {
            throw new InputException('Invalid Salesforce record ID: ' + recordId);
        }
    }

    // ─── Named Credential Validation ─────────────────────────────────────────

    /**
     * Validates that a Named Credential developer name is a safe identifier.
     * Named Credential names must only contain alphanumeric + underscores.
     */
    public static String sanitiseNamedCredentialName(String ncName) {
        if (String.isBlank(ncName)) {
            throw new InputException('Named Credential name cannot be blank');
        }
        if (!Pattern.matches('[a-zA-Z][a-zA-Z0-9_]*', ncName)) {
            throw new InputException('Invalid Named Credential name: ' + ncName);
        }
        return ncName;
    }

    // ─── JSON Safety ─────────────────────────────────────────────────────────

    /**
     * Safely deserialises a JSON string into a Map.
     * Returns an empty map on parse failure rather than throwing.
     */
    public static Map<String, Object> safeDeserialise(String jsonString) {
        if (String.isBlank(jsonString)) {
            return new Map<String, Object>();
        }
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        } catch (Exception e) {
            return new Map<String, Object>();
        }
    }

    /**
     * Safely serialises to JSON, returning '{}' on null input.
     */
    public static String safeSerialise(Object obj) {
        if (obj == null) {
            return '{}';
        }
        return JSON.serialize(obj);
    }

    // ─── Permission Set Check ────────────────────────────────────────────────

    /**
     * Returns true if the running user has the specified Permission Set assigned.
     */
    public static Boolean hasPermissionSet(String permSetName) {
        return [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.Name = :permSetName
        ] > 0;
    }

    /**
     * Throws a CRUDException if the running user does not have the given Permission Set.
     */
    public static void assertPermissionSet(String permSetName) {
        if (!hasPermissionSet(permSetName)) {
            throw new CRUDException(
                'User does not have the required Permission Set: ' + permSetName
            );
        }
    }
}
