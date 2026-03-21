/**
 * AISecurityUtilTest
 * Unit tests for the security utility class.
 */
@IsTest
private class AISecurityUtilTest {

    @IsTest
    static void testAssertReadable_Pass() {
        Test.startTest();
        try {
            AISecurityUtil.assertReadable(Account.SObjectType);
            Assert.isTrue(true, 'Should not throw for readable object');
        } catch (AISecurityUtil.CRUDException e) {
            Assert.fail('Should not throw CRUDException: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSanitisePrompt_BlankThrows() {
        Test.startTest();
        try {
            AISecurityUtil.sanitisePrompt('');
            Assert.fail('Should have thrown InputException');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(e.getMessage().contains('blank'), 'Should mention blank');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSanitisePrompt_NullThrows() {
        Test.startTest();
        try {
            AISecurityUtil.sanitisePrompt(null);
            Assert.fail('Should have thrown InputException');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(true, 'Correctly threw InputException');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSanitisePrompt_TooLongThrows() {
        String longPrompt = 'A'.repeat(32001);
        Test.startTest();
        try {
            AISecurityUtil.sanitisePrompt(longPrompt);
            Assert.fail('Should have thrown InputException for oversized prompt');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(e.getMessage().contains('32,000'), 'Should mention max length');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSanitisePrompt_RemovesNullBytes() {
        String input = 'Hello\u0000World';
        Test.startTest();
        String result = AISecurityUtil.sanitisePrompt(input);
        Test.stopTest();
        Assert.isFalse(result.contains('\u0000'), 'Null bytes should be removed');
        Assert.isTrue(result.contains('HelloWorld'), 'Content preserved');
    }

    @IsTest
    static void testSanitiseFieldName_ValidFields() {
        Test.startTest();
        Assert.areEqual('Name', AISecurityUtil.sanitiseFieldName('Name'));
        Assert.areEqual('My_Custom__c', AISecurityUtil.sanitiseFieldName('My_Custom__c'));
        Assert.areEqual('Field123', AISecurityUtil.sanitiseFieldName('Field123'));
        Test.stopTest();
    }

    @IsTest
    static void testSanitiseFieldName_InvalidThrows() {
        Test.startTest();
        try {
            AISecurityUtil.sanitiseFieldName('1invalid');
            Assert.fail('Should throw for field name starting with digit');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(true, 'Correctly rejected invalid field name');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSanitiseFieldName_InjectionThrows() {
        // Use a string variable to avoid Apex parser issues with special chars
        String injectionAttempt = 'Name' + String.fromCharArray(new List<Integer>{39}) + '; DELETE FROM Account';
        Test.startTest();
        try {
            AISecurityUtil.sanitiseFieldName(injectionAttempt);
            Assert.fail('Should throw for injection attempt');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(true, 'Correctly rejected injection attempt');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSanitiseObjectName_Valid() {
        Test.startTest();
        Assert.areEqual('Account', AISecurityUtil.sanitiseObjectName('Account'));
        Assert.areEqual('My_Object__c', AISecurityUtil.sanitiseObjectName('My_Object__c'));
        Test.stopTest();
    }

    @IsTest
    static void testSanitiseObjectName_InvalidThrows() {
        String badName = 'Account; DROP TABLE Users';
        Test.startTest();
        try {
            AISecurityUtil.sanitiseObjectName(badName);
            Assert.fail('Should throw for invalid object name');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(true, 'Correctly rejected invalid object name');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSanitiseRecordId_ValidId() {
        Account acc = new Account(Name = 'Test');
        insert acc;
        Test.startTest();
        Id result = AISecurityUtil.sanitiseRecordId(acc.Id);
        Test.stopTest();
        Assert.areEqual(acc.Id, result, 'Should return valid Id');
    }

    @IsTest
    static void testSanitiseRecordId_InvalidThrows() {
        String badId = 'not-a-valid-id';
        Test.startTest();
        try {
            AISecurityUtil.sanitiseRecordId(badId);
            Assert.fail('Should throw for invalid record ID');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(true, 'Correctly rejected invalid ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSanitiseNamedCredentialName_Valid() {
        Test.startTest();
        Assert.areEqual('AI_OpenAI', AISecurityUtil.sanitiseNamedCredentialName('AI_OpenAI'));
        Test.stopTest();
    }

    @IsTest
    static void testSanitiseNamedCredentialName_InvalidThrows() {
        String badName = 'bad name!';
        Test.startTest();
        try {
            AISecurityUtil.sanitiseNamedCredentialName(badName);
            Assert.fail('Should throw for invalid named credential name');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(true, 'Correctly rejected invalid named credential name');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSafeDeserialise_ValidJSON() {
        Test.startTest();
        Map<String, Object> result = AISecurityUtil.safeDeserialise('{"key":"value"}');
        Test.stopTest();
        Assert.areEqual('value', result.get('key'));
    }

    @IsTest
    static void testSafeDeserialise_InvalidJSON_ReturnsEmpty() {
        String badJson = 'not json {{';
        Test.startTest();
        Map<String, Object> result = AISecurityUtil.safeDeserialise(badJson);
        Test.stopTest();
        Assert.isTrue(result.isEmpty(), 'Should return empty map for invalid JSON');
    }

    @IsTest
    static void testSafeDeserialise_Null_ReturnsEmpty() {
        Test.startTest();
        Map<String, Object> result = AISecurityUtil.safeDeserialise(null);
        Test.stopTest();
        Assert.isTrue(result.isEmpty(), 'Should return empty map for null');
    }

    @IsTest
    static void testSafeSerialise_Null_ReturnsBraces() {
        Test.startTest();
        String result = AISecurityUtil.safeSerialise(null);
        Test.stopTest();
        Assert.areEqual('{}', result);
    }
}
