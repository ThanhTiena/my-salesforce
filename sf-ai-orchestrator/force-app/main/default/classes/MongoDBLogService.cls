/**
 * MongoDBLogService
 *
 * Writes audit logs and upserts/queries records via the Vercel proxy API.
 *
 * Endpoints (all under the Named Credential base URL):
 *   POST /api/salesforce/logs        — append-only audit log entry
 *   POST /api/salesforce/records     — upsert a Salesforce record snapshot
 *   GET  /api/salesforce/records     — query record(s) by sfRecordId / sfObjectType / etc.
 *
 * Write safety:
 *   - ASYNC_BEST_EFFORT (default): failures are logged but never throw — a MongoDB/Vercel
 *     error will never kill a workflow execution.
 *   - SYNC_REQUIRED: failures re-throw a MongoDBException (use during development/testing).
 *
 * Config is loaded from AI_MongoDB_Config__mdt.Default.
 * If the record is absent or Is_Active__c = false, all methods no-op.
 *
 * @author  AI Orchestration Package
 * @version 2.0
 */
public with sharing class MongoDBLogService {

    public class MongoDBException extends Exception {}

    // ─── Paths ───────────────────────────────────────────────────────────────

    private static final String PATH_LOGS    = '/api/salesforce/logs';
    private static final String PATH_RECORDS = '/api/salesforce/records';

    // ─── Config ──────────────────────────────────────────────────────────────

    private static AI_MongoDB_Config__mdt CONFIG;
    private static Boolean CONFIG_LOADED = false;

    @TestVisible
    private static AI_MongoDB_Config__mdt getConfig() {
        if (!CONFIG_LOADED) {
            List<AI_MongoDB_Config__mdt> rows = [
                SELECT Named_Credential_API_Name__c, Is_Active__c,
                       Timeout_Seconds__c, Write_Mode__c, Org_Id__c
                FROM AI_MongoDB_Config__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            CONFIG        = rows.isEmpty() ? null : rows[0];
            CONFIG_LOADED = true;
        }
        return CONFIG;
    }

    @TestVisible
    private static void setConfig(AI_MongoDB_Config__mdt mockConfig) {
        CONFIG        = mockConfig;
        CONFIG_LOADED = true;
    }

    private static Boolean isActive() {
        AI_MongoDB_Config__mdt cfg = getConfig();
        return cfg != null && cfg.Is_Active__c;
    }

    private static Boolean isSyncRequired() {
        AI_MongoDB_Config__mdt cfg = getConfig();
        return cfg != null && cfg.Write_Mode__c == 'SYNC_REQUIRED';
    }

    private static Integer timeoutSec() {
        AI_MongoDB_Config__mdt cfg = getConfig();
        return (cfg != null && cfg.Timeout_Seconds__c != null)
            ? cfg.Timeout_Seconds__c.intValue()
            : 30;
    }

    private static String ncName() {
        return getConfig().Named_Credential_API_Name__c;
    }

    // ─── Log Entry DTO ───────────────────────────────────────────────────────

    public class LogEntry {
        public String action;        // create | update | delete | sync | query | callout | custom
        public String level;         // info | warn | error
        public String message;
        public String sfOrgId;
        public String sfUserId;
        public String sfObjectType;
        public String sfRecordId;
        public String sfRecordName;
        public Map<String, Object> payload;
    }

    // ─── Record DTO ──────────────────────────────────────────────────────────

    public class SalesforceRecord {
        public String sfRecordId;    // required — upsert key
        public String sfObjectType;  // required
        public String sfOrgId;
        public String name;
        public Map<String, Object> data;
    }

    // ─── Write Log ───────────────────────────────────────────────────────────

    /**
     * Appends an immutable audit log entry.
     * POST /api/salesforce/logs
     */
    public static String writeLog(LogEntry entry) {
        if (!isActive()) return null;
        try {
            Map<String, Object> body = new Map<String, Object>{
                'action'  => entry.action,
                'level'   => entry.level,
                'message' => entry.message
            };
            if (entry.sfOrgId      != null) body.put('sfOrgId',      entry.sfOrgId);
            if (entry.sfUserId     != null) body.put('sfUserId',     entry.sfUserId);
            if (entry.sfObjectType != null) body.put('sfObjectType', entry.sfObjectType);
            if (entry.sfRecordId   != null) body.put('sfRecordId',   entry.sfRecordId);
            if (entry.sfRecordName != null) body.put('sfRecordName', entry.sfRecordName);
            if (entry.payload      != null) body.put('payload',      entry.payload);

            HttpResponse resp = post(PATH_LOGS, body);
            if (resp.getStatusCode() != 201) {
                throw new MongoDBException('writeLog HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            return (String) result.get('logId');
        } catch (Exception e) {
            handleError('writeLog', e);
            return null;
        }
    }

    /**
     * Convenience: write a log from a workflow execution context.
     */
    public static String writeExecutionLog(
        String sfObjectType,
        String sfRecordId,
        String sfRecordName,
        String action,
        String level,
        String message,
        Map<String, Object> payload
    ) {
        LogEntry entry = new LogEntry();
        entry.sfOrgId      = UserInfo.getOrganizationId();
        entry.sfUserId     = UserInfo.getUserId();
        entry.sfObjectType = sfObjectType;
        entry.sfRecordId   = sfRecordId;
        entry.sfRecordName = sfRecordName;
        entry.action       = action;
        entry.level        = level;
        entry.message      = message;
        entry.payload      = payload;
        return writeLog(entry);
    }

    // ─── Upsert Record ───────────────────────────────────────────────────────

    /**
     * Creates or updates a record snapshot in MongoDB keyed by sfRecordId.
     * POST /api/salesforce/records
     * Returns "created" or "updated".
     */
    public static String upsertRecord(SalesforceRecord record) {
        if (!isActive()) return null;
        try {
            Map<String, Object> body = new Map<String, Object>{
                'sfRecordId'   => record.sfRecordId,
                'sfObjectType' => record.sfObjectType
            };
            if (record.sfOrgId != null) body.put('sfOrgId', record.sfOrgId);
            if (record.name    != null) body.put('name',    record.name);
            if (record.data    != null) body.put('data',    record.data);

            HttpResponse resp = post(PATH_RECORDS, body);
            if (resp.getStatusCode() != 200 && resp.getStatusCode() != 201) {
                throw new MongoDBException('upsertRecord HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            return (String) result.get('operation');
        } catch (Exception e) {
            handleError('upsertRecord', e);
            return null;
        }
    }

    // ─── Query Records ───────────────────────────────────────────────────────

    /**
     * Fetch a single record by sfRecordId.
     * GET /api/salesforce/records?sfRecordId=...
     * Returns null if not found (404).
     */
    public static Map<String, Object> getRecord(String sfRecordId) {
        if (!isActive()) return null;
        try {
            HttpResponse resp = get(PATH_RECORDS + '?sfRecordId=' + EncodingUtil.urlEncode(sfRecordId, 'UTF-8'));
            if (resp.getStatusCode() == 404) return null;
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('getRecord HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            return (Map<String, Object>) result.get('record');
        } catch (Exception e) {
            handleError('getRecord', e);
            return null;
        }
    }

    /**
     * Query records with optional filters.
     * GET /api/salesforce/records?sfObjectType=Account&limit=50&skip=0
     */
    public static List<Map<String, Object>> queryRecords(
        String sfObjectType,
        String sfOrgId,
        String search,
        Integer limitRows,
        Integer skipRows
    ) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        if (!isActive()) return out;
        try {
            List<String> params = new List<String>();
            if (String.isNotBlank(sfObjectType)) params.add('sfObjectType=' + EncodingUtil.urlEncode(sfObjectType, 'UTF-8'));
            if (String.isNotBlank(sfOrgId))      params.add('sfOrgId='      + EncodingUtil.urlEncode(sfOrgId, 'UTF-8'));
            if (String.isNotBlank(search))        params.add('search='       + EncodingUtil.urlEncode(search, 'UTF-8'));
            if (limitRows != null)                params.add('limit='        + limitRows);
            if (skipRows  != null)                params.add('skip='         + skipRows);

            String qs = params.isEmpty() ? '' : '?' + String.join(params, '&');
            HttpResponse resp = get(PATH_RECORDS + qs);
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('queryRecords HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            List<Object> docs = (List<Object>) result.get('records');
            if (docs != null) {
                for (Object d : docs) {
                    out.add((Map<String, Object>) d);
                }
            }
        } catch (Exception e) {
            handleError('queryRecords', e);
        }
        return out;
    }

    // ─── Internal HTTP Helpers ────────────────────────────────────────────────

    private static HttpResponse post(String path, Map<String, Object> body) {
        return AIInferenceService.callout(
            ncName(), path, 'POST',
            new Map<String, String>{ 'x-api-key' => '{!$Credential.x-api-key}' },
            JSON.serialize(body),
            timeoutSec()
        );
    }

    private static HttpResponse get(String path) {
        return AIInferenceService.callout(
            ncName(), path, 'GET',
            new Map<String, String>{ 'x-api-key' => '{!$Credential.x-api-key}' },
            null,
            timeoutSec()
        );
    }

    // ─── Error Handler ────────────────────────────────────────────────────────

    private static void handleError(String method, Exception e) {
        System.debug(LoggingLevel.ERROR,
            'MongoDBLogService.' + method + ' failed (mode=' +
            (isSyncRequired() ? 'SYNC_REQUIRED' : 'ASYNC_BEST_EFFORT') + '): ' +
            e.getMessage()
        );
        if (isSyncRequired()) throw new MongoDBException(method + ' failed: ' + e.getMessage(), e);
    }
}
