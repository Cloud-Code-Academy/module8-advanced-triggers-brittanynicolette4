/*
AnotherOpportunityTrigger Overview

This trigger was initially created for handling various events on the Opportunity object. It was developed by a prior developer and has since been noted to cause some issues in our org.

IMPORTANT:
- This trigger does not adhere to Salesforce best practices.
- It is essential to review, understand, and refactor this trigger to ensure maintainability, performance, and prevent any inadvertent issues.

ISSUES:
Avoid nested for loop - 1 instance 
Avoid DML inside for loop - 1 instance
Bulkify Your Code - 1 instance
Avoid SOQL Query inside for loop - 2 instances 
Stop recursion - 1 instance

RESOURCES: 
https://www.salesforceben.com/12-salesforce-apex-best-practices/
https://developer.salesforce.com/blogs/developer-relations/2015/01/apex-best-practices-15-apex-commandments
*/
trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    if (Trigger.isBefore){
        if (Trigger.isInsert){
            // Set default Type for new Opportunities
            // Bulkify
            for (Opportunity opp : Trigger.new) {
            if (opp.Type == null){
                opp.Type = 'New Customer';
            }  
        }      
        } else if (Trigger.isDelete){
            // Prevent deletion of closed Opportunities
            for (Opportunity oldOpp : Trigger.old){
                if (oldOpp.IsClosed){
                    oldOpp.addError('Cannot delete closed opportunity');
                }
            }
        }
    }

    if (Trigger.isAfter){
        if (Trigger.isInsert){
            // Create a new Task for newly inserted Opportunities
            // DML in for loop
            List<Task> tasksToInsert = new List<Task>();
            for (Opportunity opp : Trigger.new){
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);
                tasksToInsert.add(tsk);
            }
                insert tasksToInsert;
            
        } else if (Trigger.isUpdate){
            // Append Stage changes in Opportunity Description
            // Nested for loop
            List<Opportunity> oppsToUpdate = new List<Opportunity>();
            for (Opportunity opp : Trigger.new){
                Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
                    if (opp.StageName != oldOpp.StageName){
                        Opportunity newOpp = new Opportunity();
                        newOpp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                        newOpp.Id = opp.Id;
                        oppsToUpdate.add(newOpp);
                    }              
            }
            update oppsToUpdate;
        }
        // Send email notifications when an Opportunity is deleted 
        else if (Trigger.isDelete){
            notifyOwnersOpportunityDeleted(Trigger.old);
        } 
        // Assign the primary contact to undeleted Opportunities
        else if (Trigger.isUndelete){
            assignPrimaryContact(Trigger.newMap);
        }
    }


    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    // SOQL in for loop
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {

        Map<Id, User> users = new Map<Id, User>([SELECT Id, Email FROM User]);
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            User owner = users.get(opp.OwnerId);
            List<String> toAddresses = new List<String> {owner.Email};
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }

    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    // SOQL in for loop
    private static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {        
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : oppNewMap.values()) {
        oppIds.add(opp.AccountId);
    }
        List<Contact> primaryContacts = [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId IN :oppIds LIMIT 1];
        Map<Id, Contact> accountToContact = new Map<Id, Contact>();
        for (Contact con : primaryContacts){
            accountToContact.put(con.AccountId, con);
        }
        for (Opportunity opp : oppNewMap.values()){            
            if (opp.Primary_Contact__c == null){
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                Contact primaryContact = accountToContact.get(opp.AccountId);
                oppToUpdate.Primary_Contact__c = primaryContact.Id;
                oppMap.put(opp.Id, oppToUpdate);
            }
        }
        update oppMap.values();
    }
}