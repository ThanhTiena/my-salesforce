({
    handleContactSelect: function (component, event) {
        var service = component.find('service');

        component.set('v.contactId', event.getParam('contactId'));
        service.reloadRecord();
    },
    
    init: function(component, event, helper){
     
        var path = $A.get("$Resource.data");
        var req = new XMLHttpRequest();
        req.open("GET", path);
        req.addEventListener("load", $A.getCallback(function() {
            component.set('v.columns', [
            	{ label: 'A', fieldName: 'taxSaleItemLink',originalFieldName: "TXS_Parcel__c", type: 'url', sortable: true, typeAttributes: { label: { fieldName: "Parcel_Number__c" } } },
                { label: "File_Status__c", fieldName: "File_Status__c", type: "text", sortable: true },
                { label: "Status_Code__c", fieldName: "Status_Code__c", type: "text", sortable: true },
                { label: "Owner_Occupied__c", fieldName: "Owner_Occupied__c", type: "text", sortable: true },
                { label: "Improved_Property__c", fieldName: "Improved_Property__c", type: "text", sortable: true },
                { label: "Timeshare__c", fieldName: "Timeshare__c", type: "text", sortable: true },
                { label: "Origin_Defaulted_Amount__c", fieldName: "Origin_Defaulted_Amount__c", type: "text", sortable: true },
                { label: "Suspense_Amount__c", fieldName: "Suspense_Amount__c", type: "text", sortable: true },
                { label: "Defaulted_Credit_Amount__c", fieldName: "Defaulted_Credit_Amount__c", type: "text", sortable: true },
                { label: "Current_Default_Amount__c", fieldName: "Current_Default_Amount__c", type: "text", sortable: true },
                { label: "Tax_Sale_Fee__c", fieldName: "Tax_Sale_Fee__c", type: "text", sortable: true },
                { label: "Value_Land__c", fieldName: "Value_Land__c", type: "text", sortable: true },
                { label: "Value_Improvement__c", fieldName: "Value_Improvement__c", type: "text", sortable: true },
                { label: "EXEMP_HO__c", fieldName: "EXEMP_HO__c", type: "text", sortable: true },
                { label: "Comments__c", fieldName: "Comments__c", type: "text", sortable: true },
                { label: "Recommend_Suggestive_Minimum_Bid__c", fieldName: "Recommend_Suggestive_Minimum_Bid__c", type: "text", sortable: true },
                { label: "Minimum_Bid_Remarks__c", fieldName: "Minimum_Bid_Remarks__c", type: "text", sortable: true },
                { label: "Minimum_Bid_Approved_By__c", fieldName: "Minimum_Bid_Approved_By__c", type: "text", sortable: true }

            ]);
            component.set('v.data', JSON.parse(req.response));
        }));
        req.send(null);
        
    }
});