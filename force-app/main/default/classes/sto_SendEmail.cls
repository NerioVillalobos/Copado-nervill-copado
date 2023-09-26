/*---------------------------------------------------------------------------------------------------------------
--- Company: LabsXD
--- Author: Victor Pacheco
--- Description: Clase que permite actualizar los atributos del producto tecnico
--- CreateDate: 13/02/2023
--- Update for: 
--- UpdateDate: 
--- Update Description: 
---------------------------------------------------------------------------------------------------------------*/
global with sharing class sto_SendEmail implements vlocity_cmt.VlocityOpenInterface2 {
    private static String DISPLAY_NAME = 'Sky';
    //Traer año actual para template de confirmacion de compra y recordatorio falta de pago
    Date fechaActual = System.today();
    Integer yearint = fechaActual.year();
    String  year = String.valueOf(yearint);
    class notificationException extends Exception{}
    //Method Names
    @TestVisible
    private static final String METHOD_SEND_EMAIL_CONFIRMATION = 'sendEmailConfirmation';
    
    @TestVisible
    private static final String METHOD_SEND_EMAIL_CANCELLATION = 'sendEmailCancellation';
    
    @TestVisible
    private static final String METHOD_SEND_EMAIL_REMINDER = 'sendEmailReminder';
    
    //Input Parameters
    @TestVisible
    private static String INPUT_ARGUMENTS = 'arguments';
	
    global Object invokeMethod(String methodName, Map < String, Object > inputMap, Map < String, Object > outMap, Map < String, Object > options) {
        try {
			System.debug('methodName ->' + methodName);
            
            if (METHOD_SEND_EMAIL_CONFIRMATION.equalsIgnoreCase(methodName)) {
                return sendEmailConfirmation(inputMap, outMap, options);
            } else if (METHOD_SEND_EMAIL_CANCELLATION.equalsIgnoreCase(methodName)) {
                return sendEmailCancellation(inputMap, outMap, options);
            } else if (METHOD_SEND_EMAIL_REMINDER.equalsIgnoreCase(methodName)) {
                return sendEmailReminder(inputMap, outMap, options);
            }  
            else if (methodName == '') {
                throw new notificationException('No method name');
            } else {
                return false;
            }
        } catch (Exception thrownException) {
            return false;
        }

    }
    

    private Boolean sendEmailConfirmation(Map < String, Object > inputMap, Map < String, Object > outMap, Map < String, Object > options) {
        system.debug('Inicio');
        
        system.debug('inputMap ' + json.serializePretty(inputMap) );   
        try{
            string orderId = (string)inputMap.get('orderId');

            Order order = [SELECT id, OrderNumber, AccountId
                               FROM Order
                               WHERE Id =: orderId];            
                
            OrderItem oItem = [SELECT Id, Product2.Name 
                                FROM OrderItem WHERE OrderId =: order.Id 
                                AND Product2.vlocity_cmt__SubType__c = 'Principal' Limit 1];
                            
            string email_template = 'Confirmacion';
            
            EmailTemplate et = [SELECT Id, HtmlValue, Subject
                                FROM EmailTemplate
                                WHERE DeveloperName = :email_template];
                
            String htmlBody = et?.HtmlValue;
                
            Account[] a = [SELECT id, Name, Cliente_nuevo__c
                            FROM Account
                            WHERE id = :order.AccountId];
            
			List<Contact> contacts = new List<Contact> ();
            if(a[0].Cliente_nuevo__c == true){
                contacts = [SELECT id, Email
                                        FROM Contact
                                        WHERE AccountId = :a[0].id 
                                        AND Email != ''];
            } else {
                contacts = [SELECT id, Email
                                        FROM Contact
                                        WHERE AccountId = :a[0].id 
                                        AND Email != '' AND ContactoWWW__c = true];
            }

            if(contacts.size()<1){
                throw new notificationException('No email contacts to account id=' + a[0].id);
            }
                
            system.debug('htmlBody:::' + htmlBody);
                
            htmlBody = htmlBody.replace('$%nombre$%', a[0]?.Name);
            htmlBody = htmlBody.replace('$%nombre del paquete$%', oItem.Product2.Name);
            htmlBody = htmlBody.replace('$%año%$','2023');

            List<String> toAddress = new List<String>();
            toAddress.add(contacts[0]?.Email);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(contacts[0]?.id);
            mail.setTemplateId(et?.id);
            mail.setHtmlBody(htmlBody);
            mail.setToAddresses(toAddress);
            mail.setSubject(et?.Subject);
            mail.setWhatId(a[0]?.id);
            mail.setSaveAsActivity(false);
            mail.setUseSignature(false);
                
            OrgwideEmailAddress orgwideaddress = [SELECT id, displayname, Address
                                                FROM orgwideEmailAddress
                                                WHERE DisplayName = :DISPLAY_NAME
                                                LIMIT 1];

            system.debug('orgwideaddress->' + orgwideaddress);
            
            mail.setOrgWideEmailAddressId(orgwideaddress?.Id);
						 
            List<Messaging.SingleEmailMessage> allmsg = new List<Messaging.SingleEmailMessage>();
            allmsg.add(mail);
            
            Messaging.sendEmail(allmsg, true);
            System.debug(logginglevel.DEBUG,'Number of emails sent by the execution: ' + System.Limits.getEmailInvocations());
            return true;
        }
        catch(Exception e){
            outMap.put('Error', 'Error- Check in the line : ' + e.getLineNumber() + ' for possible null or incorrect value. Query is empty' + ' Cause: ' +e.getCause() + 'StackTrace: ' + e.getStackTraceString() + e.getMessage());
            switch on e.getTypeName() {
                when 'QueryException' {
                    System.debug(
                        System.LoggingLevel.ERROR,
                        'Error- Check in the line : ' +
                        e.getLineNumber() +
                        ' for possible null or incorrect value. Query is empty' +
                        ' Cause: ' +
                        e.getCause() +
                        'StackTrace: ' +
                        e.getStackTraceString() +
                        e.getMessage()
                    );
                }
                when 'EmailException' {
                    System.debug(
                        e.getMessage() +
                        ' \n' +
                        e.getLineNumber() +
                        ' \n' +
                        e.getCause()
                    );
                }
                when 'NullPointerException' {
                    System.debug(e.getMessage() + ' \n' + e.getCause());
                }
                when else {
                    System.debug(e.getMessage() + ' \n' + e.getCause());
                }
            }
            return false;
        }
    }
     
    private Boolean sendEmailCancellation(Map < String, Object > inputMap, Map < String, Object > outMap, Map < String, Object > options) {
        system.debug('Inicio');
        
        system.debug('inputMap ' + json.serializePretty(inputMap) );   
        try{
            string orderId = (string)inputMap.get('orderId');

            Order order = [SELECT id, OrderNumber, AccountId
                               FROM Order
                               WHERE Id =: orderId];            
                
            /*OrderItem oItem = [SELECT Id, Product2.Name 
                                FROM OrderItem WHERE OrderId =: order.Id 
                                AND Product2.vlocity_cmt__SubType__c = 'Principal' Limit 1];*/
                            
            string email_template = 'CancelacionFaltaPago';
            
            EmailTemplate et = [SELECT Id, HtmlValue, Subject
                                FROM EmailTemplate
                                WHERE DeveloperName = :email_template];
                
            String htmlBody = et?.HtmlValue;
                
            Account[] a = [SELECT id, Name, Cliente_nuevo__c
                            FROM Account
                            WHERE id = :order.AccountId];
            
			List<Contact> contacts = new List<Contact> ();
            if(a[0].Cliente_nuevo__c == true){
                contacts = [SELECT id, Email
                                        FROM Contact
                                        WHERE AccountId = :a[0].id 
                                        AND Email != ''];
            } else {
                contacts = [SELECT id, Email
                                        FROM Contact
                                        WHERE AccountId = :a[0].id 
                                        AND Email != '' AND ContactoWWW__c = true];
            }

            if(contacts.size()<1){
                throw new notificationException('No email contacts to account id=' + a[0].id);
            }
                
            system.debug('htmlBody:::' + htmlBody);
                
            htmlBody = htmlBody.replace('$%nombre%$', a[0]?.Name);

            List<String> toAddress = new List<String>();
            toAddress.add(contacts[0]?.Email);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(contacts[0]?.id);
            mail.setTemplateId(et?.id);
            mail.setHtmlBody(htmlBody);
            mail.setToAddresses(toAddress);
            mail.setSubject(et?.Subject);
            mail.setWhatId(a[0]?.id);
            mail.setSaveAsActivity(false);
            mail.setUseSignature(false);
                
            OrgwideEmailAddress orgwideaddress = [SELECT id, displayname, Address
                                                FROM orgwideEmailAddress
                                                WHERE DisplayName = :DISPLAY_NAME
                                                LIMIT 1];

            system.debug('orgwideaddress->' + orgwideaddress);
            
            mail.setOrgWideEmailAddressId(orgwideaddress?.Id);
						 
            List<Messaging.SingleEmailMessage> allmsg = new List<Messaging.SingleEmailMessage>();
            allmsg.add(mail);
            
            Messaging.sendEmail(allmsg, true);
            System.debug(logginglevel.DEBUG,'Number of emails sent by the execution: ' + System.Limits.getEmailInvocations());
            return true;
        }
        catch(Exception e){
            outMap.put('Error', 'Error- Check in the line : ' + e.getLineNumber() + ' for possible null or incorrect value. Query is empty' + ' Cause: ' +e.getCause() + 'StackTrace: ' + e.getStackTraceString() + e.getMessage());
            switch on e.getTypeName() {
                when 'QueryException' {
                    System.debug(
                        System.LoggingLevel.ERROR,
                        'Error- Check in the line : ' +
                        e.getLineNumber() +
                        ' for possible null or incorrect value. Query is empty' +
                        ' Cause: ' +
                        e.getCause() +
                        'StackTrace: ' +
                        e.getStackTraceString() +
                        e.getMessage()
                    );
                }
                when 'EmailException' {
                    System.debug(
                        e.getMessage() +
                        ' \n' +
                        e.getLineNumber() +
                        ' \n' +
                        e.getCause()
                    );
                }
                when 'NullPointerException' {
                    System.debug(e.getMessage() + ' \n' + e.getCause());
                }
                when else {
                    System.debug(e.getMessage() + ' \n' + e.getCause());
                }
            }
            return false;
        }
    }
    
    private Boolean sendEmailReminder(Map < String, Object > inputMap, Map < String, Object > outMap, Map < String, Object > options) {
        system.debug('Inicio');
        
        system.debug('inputMap ' + json.serializePretty(inputMap) );   
        try{
            List<Id> orderIdLst = (List<Id>)inputMap.get('orderIdLst');

            List<Order> orderLst = [SELECT id, OrderNumber, AccountId
                               FROM Order
                               WHERE Id IN: orderIdLst];            
                
            string email_template = 'RecordatorioFaltaPago';
            
            EmailTemplate et = [SELECT Id, HtmlValue, Subject
                                FROM EmailTemplate
                                WHERE DeveloperName = :email_template];
                
            String htmlBodyOriginal = et?.HtmlValue;
            
            List<Id> accIdLst = new List<Id>();
            for(Order ord: orderLst){
                accIdLst.add(ord.AccountId);
            }

            List<Account> accLst = [SELECT id, Name, Cliente_nuevo__c
                            FROM Account
                            WHERE id IN :accIdLst];
            
			List<Contact> contacts = new List<Contact> ();
 
            OrgwideEmailAddress orgwideaddress = [SELECT id, displayname, Address
                                                FROM orgwideEmailAddress
                                                WHERE DisplayName = :DISPLAY_NAME
                                                LIMIT 1];

            List<Messaging.SingleEmailMessage> allmsg = new List<Messaging.SingleEmailMessage>();
            List<Account> accErrorLst = new List<Account>();
            for(Account acc: accLst){
                if(acc.Cliente_nuevo__c == true){
                    contacts = [SELECT id, Email
                                        FROM Contact
                                        WHERE AccountId = :acc.id 
                                        AND Email != ''];
                } else {
                    contacts = [SELECT id, Email
                                            FROM Contact
                                            WHERE AccountId = :acc.id 
                                            AND Email != '' AND ContactoWWW__c = true];
                }

                if(contacts.size()<1){
                    accErrorLst.add(acc);
                }
                
                string htmlBody = htmlBodyOriginal;
                htmlBody = htmlBody.replace('$%nombre%$', acc.Name);
                htmlBody = htmlBody.replace('$%año%$','2023');
    
                List<String> toAddress = new List<String>();
                toAddress.add(contacts[0]?.Email);
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(contacts[0]?.id);
                mail.setTemplateId(et?.id);
                mail.setHtmlBody(htmlBody);
                mail.setToAddresses(toAddress);
                mail.setSubject(et?.Subject);
                mail.setWhatId(acc.id);
                mail.setSaveAsActivity(false);
                mail.setUseSignature(false);
                mail.setOrgWideEmailAddressId(orgwideaddress?.Id);
                allmsg.add(mail);
            }                        		 
                        
            Messaging.sendEmail(allmsg, true);
            System.debug(logginglevel.DEBUG,'Number of emails sent by the execution: ' + System.Limits.getEmailInvocations());
            return true;
        }
        catch(Exception e){
            outMap.put('Error', 'Error- Check in the line : ' + e.getLineNumber() + ' for possible null or incorrect value. Query is empty' + ' Cause: ' +e.getCause() + 'StackTrace: ' + e.getStackTraceString() + e.getMessage());
            switch on e.getTypeName() {
                when 'QueryException' {
                    System.debug(
                        System.LoggingLevel.ERROR,
                        'Error- Check in the line : ' +
                        e.getLineNumber() +
                        ' for possible null or incorrect value. Query is empty' +
                        ' Cause: ' +
                        e.getCause() +
                        'StackTrace: ' +
                        e.getStackTraceString() +
                        e.getMessage()
                    );
                }
                when 'EmailException' {
                    System.debug(
                        e.getMessage() +
                        ' \n' +
                        e.getLineNumber() +
                        ' \n' +
                        e.getCause()
                    );
                }
                when 'NullPointerException' {
                    System.debug(e.getMessage() + ' \n' + e.getCause());
                }
                when else {
                    System.debug(e.getMessage() + ' \n' + e.getCause());
                }
            }
            return false;
        }
    }
/*
    private Boolean sendEmailReminder(Map < String, Object > inputMap, Map < String, Object > outMap, Map < String, Object > options) {
        system.debug('Inicio');
        
        system.debug('inputMap ' + json.serializePretty(inputMap) );   
        try{
            string orderId = (string)inputMap.get('orderId');

            Order order = [SELECT id, OrderNumber, AccountId
                               FROM Order
                               WHERE Id =: orderId];            
                
            string email_template = 'RecordatorioFaltaPago';
            
            EmailTemplate et = [SELECT Id, HtmlValue, Subject
                                FROM EmailTemplate
                                WHERE DeveloperName = :email_template];
                
            String htmlBody = et?.HtmlValue;
                
            Account[] a = [SELECT id, Name, Cliente_nuevo__c
                            FROM Account
                            WHERE id = :order.AccountId];
            
			List<Contact> contacts = new List<Contact> ();
            if(a[0].Cliente_nuevo__c == true){
                contacts = [SELECT id, Email
                                        FROM Contact
                                        WHERE AccountId = :a[0].id 
                                        AND Email != ''];
            } else {
                contacts = [SELECT id, Email
                                        FROM Contact
                                        WHERE AccountId = :a[0].id 
                                        AND Email != '' AND ContactoWWW__c = true];
            }

            if(contacts.size()<1){
                throw new notificationException('No email contacts to account id=' + a[0].id);
            }
                
            system.debug('htmlBody:::' + htmlBody);
                
            htmlBody = htmlBody.replace('$%nombre%$', a[0]?.Name);

            List<String> toAddress = new List<String>();
            toAddress.add(contacts[0]?.Email);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(contacts[0]?.id);
            mail.setTemplateId(et?.id);
            mail.setHtmlBody(htmlBody);
            mail.setToAddresses(toAddress);
            mail.setSubject(et?.Subject);
            mail.setWhatId(a[0]?.id);
            mail.setSaveAsActivity(false);
            mail.setUseSignature(false);
                
            OrgwideEmailAddress orgwideaddress = [SELECT id, displayname, Address
                                                FROM orgwideEmailAddress
                                                WHERE DisplayName = :DISPLAY_NAME
                                                LIMIT 1];

            system.debug('orgwideaddress->' + orgwideaddress);
            
            mail.setOrgWideEmailAddressId(orgwideaddress?.Id);
						 
            List<Messaging.SingleEmailMessage> allmsg = new List<Messaging.SingleEmailMessage>();
            allmsg.add(mail);
            
            Messaging.sendEmail(allmsg, true);
            System.debug(logginglevel.DEBUG,'Number of emails sent by the execution: ' + System.Limits.getEmailInvocations());
            return true;
        }
        catch(Exception e){
            switch on e.getTypeName() {
                when 'QueryException' {
                    System.debug(
                        System.LoggingLevel.ERROR,
                        'Error- Check in the line : ' +
                        e.getLineNumber() +
                        ' for possible null or incorrect value. Query is empty' +
                        ' Cause: ' +
                        e.getCause() +
                        'StackTrace: ' +
                        e.getStackTraceString() +
                        e.getMessage()
                    );
                }
                when 'EmailException' {
                    System.debug(
                        e.getMessage() +
                        ' \n' +
                        e.getLineNumber() +
                        ' \n' +
                        e.getCause()
                    );
                }
                when 'NullPointerException' {
                    System.debug(e.getMessage() + ' \n' + e.getCause());
                }
                when else {
                    System.debug(e.getMessage() + ' \n' + e.getCause());
                }
            }
            return false;
        }
    }*/
}