/**
 * AIPromptTemplateServiceTest
 * Unit tests for prompt template resolution and injection prevention.
 */
@IsTest
private class AIPromptTemplateServiceTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Acme Corp', Phone = '555-1234');
        insert acc;
    }

    @IsTest
    static void testResolveBasicVariable() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        Test.startTest();
        String resolved = AIPromptTemplateService.resolve(
            'Analyse account: {{Account.Name}}',
            acc.Id,
            'Account'
        );
        Test.stopTest();
        Assert.isTrue(resolved.contains('Acme Corp'), 'Should interpolate Name field');
        Assert.isFalse(resolved.contains('{{'), 'Should remove all tokens');
    }

    @IsTest
    static void testResolveMultipleVariables() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        Test.startTest();
        String resolved = AIPromptTemplateService.resolve(
            'Account: {{Account.Name}}, Phone: {{Account.Phone}}',
            acc.Id,
            'Account'
        );
        Test.stopTest();
        Assert.isTrue(resolved.contains('Acme Corp'));
        Assert.isTrue(resolved.contains('555-1234'));
    }

    @IsTest
    static void testResolveNoVariables() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        Test.startTest();
        String resolved = AIPromptTemplateService.resolve(
            'Simple prompt with no variables.',
            acc.Id,
            'Account'
        );
        Test.stopTest();
        Assert.areEqual('Simple prompt with no variables.', resolved);
    }

    @IsTest
    static void testResolveWithMap() {
        Map<String, String> vars = new Map<String, String>{
            'Account.Name'    => 'Test Corp',
            'Account.Website' => 'https://test.com'
        };
        Test.startTest();
        String resolved = AIPromptTemplateService.resolveWithMap(
            'Company: {{Account.Name}}, URL: {{Account.Website}}',
            vars
        );
        Test.stopTest();
        Assert.isTrue(resolved.contains('Test Corp'));
        Assert.isTrue(resolved.contains('https://test.com'));
    }

    @IsTest
    static void testBlankTemplateThrows() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        Test.startTest();
        try {
            AIPromptTemplateService.resolve('', acc.Id, 'Account');
            Assert.fail('Should throw for blank template');
        } catch (AIPromptTemplateService.TemplateException e) {
            Assert.isTrue(true, 'Correctly rejected blank template');
        }
        Test.stopTest();
    }

    @IsTest
    static void testInvalidObjectNameThrows() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        String badObjectName = 'Account; DROP TABLE';
        Test.startTest();
        try {
            AIPromptTemplateService.resolve('Test {{Account.Name}}', acc.Id, badObjectName);
            Assert.fail('Should throw for invalid object name');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(true, 'Correctly rejected invalid object name');
        }
        Test.stopTest();
    }

    @IsTest
    static void testUnknownObjectThrows() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1];
        Test.startTest();
        try {
            // Object name in token must match the objectName param to trigger the lookup
            AIPromptTemplateService.resolve('Test {{FakeObject__c.Name}}', acc.Id, 'FakeObject__c');
            Assert.fail('Should throw for unknown object');
        } catch (AIPromptTemplateService.TemplateException e) {
            Assert.isTrue(true, 'Correctly rejected unknown object');
        }
        Test.stopTest();
    }

    @IsTest
    static void testPromptInjectionInFieldValue() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String evilName = 'Evil {{Account.Phone}} Corp';
        update new Account(Id = acc.Id, Name = evilName);

        Test.startTest();
        String resolved = AIPromptTemplateService.resolve(
            'Account: {{Account.Name}}',
            acc.Id,
            'Account'
        );
        Test.stopTest();
        Assert.isFalse(resolved.contains('{{Account.Phone}}'), 'Nested template tokens should be escaped');
    }

    @IsTest
    static void testRecordNotFoundThrows() {
        Id fakeId = '001000000000001AAA';
        Test.startTest();
        try {
            AIPromptTemplateService.resolve('Test {{Account.Name}}', fakeId, 'Account');
            Assert.fail('Should throw for non-existent record');
        } catch (AIPromptTemplateService.TemplateException e) {
            Assert.isTrue(e.getMessage().contains('not found'));
        }
        Test.stopTest();
    }
}
