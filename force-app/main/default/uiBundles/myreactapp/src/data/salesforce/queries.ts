/**
 * Salesforce GraphQL operation strings (uiapi).
 *
 * Pattern (per the Salesforce React UI Bundle guidance):
 *   - Everything nests under `uiapi.query.<Object>`.
 *   - Relay connection shape: `edges { node { ... } }`.
 *   - Scalar fields use `Field @optional { value }`; `Id` is bare.
 *   - Filter/sort with `where`, `first`, `orderBy`; pass values via variables.
 *
 * These read the FreelanceOps objects deployed by this project. Field API names
 * match the metadata under force-app/main/default/objects.
 */

export const ACCOUNTS_QUERY = /* GraphQL */ `
  query FopsAccounts($first: Int = 50) {
    uiapi {
      query {
        Account(first: $first, orderBy: { Name: { order: ASC } }) {
          edges {
            node {
              Id
              Name @optional { value }
              Phone @optional { value }
              FOPS_Account_Role__c @optional { value }
              FOPS_Client_Health__c @optional { value }
              FOPS_Default_Invoice_Currency__c @optional { value }
            }
          }
        }
      }
    }
  }
`;

export const ASSIGNMENTS_QUERY = /* GraphQL */ `
  query FopsAssignments($first: Int = 50) {
    uiapi {
      query {
        FOPS_Assignment__c(first: $first, orderBy: { CreatedDate: { order: DESC } }) {
          edges {
            node {
              Id
              Name @optional { value }
              FOPS_Status__c @optional { value }
              FOPS_Start_Date__c @optional { value }
              FOPS_End_Date__c @optional { value }
              FOPS_Hours_Per_Week__c @optional { value }
              FOPS_Consultant__r { Name @optional { value } }
              FOPS_End_Client__r { Name @optional { value } }
            }
          }
        }
      }
    }
  }
`;

export const INVOICES_QUERY = /* GraphQL */ `
  query FopsInvoices($first: Int = 50) {
    uiapi {
      query {
        Order(first: $first, orderBy: { EffectiveDate: { order: DESC } }) {
          edges {
            node {
              Id
              OrderNumber @optional { value }
              Status @optional { value }
              EffectiveDate @optional { value }
              FOPS_Invoice_Number__c @optional { value }
              FOPS_Invoice_Status__c @optional { value }
              FOPS_Due_Date__c @optional { value }
              FOPS_Total_Amount_Base__c @optional { value }
              FOPS_Balance_Due__c @optional { value }
              Account { Name @optional { value } }
            }
          }
        }
      }
    }
  }
`;

export const TIME_ENTRIES_QUERY = /* GraphQL */ `
  query FopsTimeEntries($first: Int = 100) {
    uiapi {
      query {
        FOPS_Time_Entry__c(first: $first, orderBy: { FOPS_Work_Date__c: { order: DESC } }) {
          edges {
            node {
              Id
              Name @optional { value }
              FOPS_Work_Date__c @optional { value }
              FOPS_Hours__c @optional { value }
              FOPS_Is_Billable__c @optional { value }
              FOPS_Description__c @optional { value }
            }
          }
        }
      }
    }
  }
`;

/** Update an Account's client-health picklist — sample mutation. */
export const ACCOUNT_UPDATE_MUTATION = /* GraphQL */ `
  mutation UpdateAccountHealth($input: AccountUpdateInput!) {
    uiapi {
      AccountUpdate(input: $input) {
        Record {
          Id
          FOPS_Client_Health__c { value }
        }
      }
    }
  }
`;
