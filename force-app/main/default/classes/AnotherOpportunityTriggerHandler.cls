public with sharing class AnotherOpportunityTriggerHandler {

    public static void setCustomer(List<Opportunity> opps){
                for (Opportunity opp : opps) {
                if (opp.Type == null){
                    opp.Type = 'New Customer';
                    }  
                }      
            } 
            public static void deleteOpportunity(List<Opportunity> opps){
                for (Opportunity oldOpp : opps){
                    if (oldOpp.IsClosed){
                        oldOpp.addError('Cannot delete closed opportunity');
                    }
                }
            }
    
        public static void taskInsert(List<Opportunity> opps){
                List<Task> tasksToInsert = new List<Task>();
                for (Opportunity opp : opps){
                    Task tsk = new Task();
                    tsk.Subject = 'Call Primary Contact';
                    tsk.WhatId = opp.Id;
                    tsk.WhoId = opp.Primary_Contact__c;
                    tsk.OwnerId = opp.OwnerId;
                    tsk.ActivityDate = Date.today().addDays(3);
                    tasksToInsert.add(tsk);
                }
                    insert tasksToInsert;
                
            } 
            public static void oppStageUpdate(Map<Id, Opportunity> oldMap, Map<Id, Opportunity> newMap){
                List<Opportunity> oppsToUpdate = new List<Opportunity>();
                for (Opportunity opp : newMap.values()){
                    Opportunity oldOpp = oldMap.get(opp.Id);
                        if (opp.StageName != oldOpp.StageName){
                            Opportunity newOpp = new Opportunity();
                            newOpp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                            newOpp.Id = opp.Id;
                            oppsToUpdate.add(newOpp);
                        }              
                }
                update oppsToUpdate;
            }
            public static void afterDelete(List<Opportunity> opps){
                notifyOwnersOpportunityDeleted(opps);
            } 
            public static void afterUndelete(List<Opportunity> opps){
                assignPrimaryContact(opps);
            }
    
            public static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
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
            } 
            catch (Exception e){
                System.debug('Exception: ' + e.getMessage());
            }
        }
    
   
        public static void assignPrimaryContact(List<Opportunity> opps) {        
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
            Set<Id> oppIds = new Set<Id>();
            for (Opportunity opp : opps) {
                if (opp.Primary_Contact__c == null && opp.AccountId != null){
                    oppIds.add(opp.AccountId);
                }
        }
            List<Contact> primaryContacts = [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId IN :oppIds];
            Map<Id, Contact> accountToContact = new Map<Id, Contact>();
            for (Contact con : primaryContacts){
                accountToContact.put(con.AccountId, con);
            }
            for (Opportunity opp : opps){            
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
    
