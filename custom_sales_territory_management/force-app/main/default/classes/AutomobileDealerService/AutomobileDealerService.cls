public class AutomobileDealerService
{
    private static List<Assignment_History__c> assignmentsHistoryToInsert { get; private set; }
    public static final String ZIP_CODE_ERROR_MESSAGE = 'The zip code is already assigned to three sales representatives';
    
    public AutomobileDealerService()
    {
        assignmentsHistoryToInsert = new List<Assignment_History__c>();
    }

    // use a random function to select one of the assigned sales representatives
    private static Territory__c GetRandomTerritory(List<Territory__c> territories)
    {
        Integer territoriesSize = territories.size();
        if (territoriesSize > 0)
        {
            Integer randomInt = Math.floor(Math.random()).intValue();
            Integer randomIndex = Math.Mod(randomInt, territoriesSize);
            return territories[randomIndex];
        }

        return null;
    }

    private static cstm_AccountHistory__c GetLastAutoDealerHistory(Id dealerAccountId)
    {
        List<cstm_AccountHistory__c> oldZipCodeAutoDealerHistory = 
        [
            SELECT Id, Accounts__c, OldValue__c, CreatedById
            FROM cstm_AccountHistory__c
            WHERE Field__c = 'BillingPostalCode'
            AND Accounts__c = :dealerAccountId
            ORDER BY CreatedDate DESC
        ];

        return oldZipCodeAutoDealerHistory.isEmpty() ? null : oldZipCodeAutoDealerHistory[0];
    } 

    private static Id GetLastTerritoryId(Id territoryId)
    {
        List<Assignment_History__c> oldAssigmentHistory = 
        [
            SELECT New_Territory__c, Previous_Territory__c
            FROM Assignment_History__c
            WHERE New_Territory__c = :territoryId
            ORDER BY CreatedDate DESC
        ];

        return oldAssigmentHistory.isEmpty() ? null : oldAssigmentHistory[0].Previous_Territory__c;
    }

    private static void StoreAssignmentHistory(
        Id prevOwner, 
        Id newOwner, 
        Id prevTerritoryId, 
        Id newTerritoryId, 
        Id autoDealerId, 
        Id createdById
    )
    {
        Assignment_History__c newAssignment = new Assignment_History__c
        (
            Previous_Owner__c = prevOwner,
            New_Owner__c = newOwner,
            Previous_Territory__c = prevTerritoryId,
            New_Territory__c = newTerritoryId,
            Account__c = autoDealerId,
            Changed_By__c = createdById
        );

        assignmentsHistoryToInsert.add(newAssignment);
    }
    
    // Change the Account Owner to the sales representative assigned to the new zip code
    private static Account ReassignAccountOwner(Territory__c associatedTerritory, Account dealerAccount)
    {
        cstm_AccountHistory__c prevAutoDealerHistory = GetLastAutoDealerHistory(dealerAccount.Id);

        String OldZipCode = null;
        Id OldCreatedBy = null;
        Id prevTerritoryId = GetLastTerritoryId(associatedTerritory.Id);

        if (prevAutoDealerHistory != null)
        {
            OldZipCode = prevAutoDealerHistory.OldValue__c;
            OldCreatedBy = prevAutoDealerHistory.CreatedById;
        }

        StoreAssignmentHistory(
            dealerAccount.OwnerId, 
            associatedTerritory.Owner__c,
            prevTerritoryId,
            associatedTerritory.Id,
            dealerAccount.Id,
            OldCreatedBy
        );

        dealerAccount.OwnerId = associatedTerritory.Owner__c;
        return dealerAccount;
    }

    // Change the Owner field of all the Account’s Contacts to the same sales rep
    private static List<Contact> ReassignContactsOwner(Account dealerAccount, Id newOwnerId)
    {
        List<Contact> contactsToReassign = new List<Contact>();
        List<Contact> dealerEmployees = 
        [
            SELECT Id, AccountId 
            FROM Contact
            WHERE AccountId = :dealerAccount.Id
        ];

        for (Contact employeeToUpdate : dealerEmployees)
        {
            employeeToUpdate.OwnerId = newOwnerId;
            contactsToReassign.add(employeeToUpdate);
        }

        return contactsToReassign;
    }

    // Change the Owner field of all the Account’s Open Opportunities to the same sales rep
    private static List<Opportunity> ReassignOpenOpportunitiesOwner(Account dealerAccount, Id newOwnerId)
    {
        List<Opportunity> openOppsToReassign = new List<Opportunity>();
        List<Opportunity> dealerOpenOpportunities = 
        [
            SELECT Id, OwnerId, AccountId, IsClosed
            FROM Opportunity
            WHERE AccountId = :dealerAccount.Id
            AND IsClosed = false
        ];

        for (Opportunity opportunityToUpdate : dealerOpenOpportunities)
        {
            opportunityToUpdate.OwnerId = newOwnerId;
            openOppsToReassign.add(opportunityToUpdate);
        }

        return openOppsToReassign;
    }

    @future
    private static void UpdateDataModelOwnersByAccountsId(Set<Id> updatedAccountsId)
    {
        List<Account> updatedAccounts = 
        [
            SELECT Id, OwnerId, BillingPostalCode
            FROM Account
            WHERE Id IN :updatedAccountsId
        ];
        
        Set<String> billingPostalCodes = new Set<String>();
        for (Account acc : updatedAccounts)
            billingPostalCodes.add(acc.BillingPostalCode);

        List<Territory__c> relatedTerritories = 
        [
            SELECT Id, Owner__c, Zip_Code__c
            FROM Territory__c
            WHERE Zip_Code__c IN :billingPostalCodes
        ];

        List<Contact> contactsToUpdate = new List<Contact>();
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        List<Account> accountsToUpdate = new List<Account>();

        for (Account updatedAcc : updatedAccounts)
        {
            List<Territory__c> territories = new List<Territory__c>();
            String zipCode = updatedAcc.BillingPostalCode;

            for (Territory__c territory : relatedTerritories)
            {
                if (territory.Zip_Code__c == zipCode)
                    territories.add(territory);
            }

            Territory__c associatedTerritory = GetRandomTerritory(territories);
        
            if (associatedTerritory != null)
            {
                if (territories.size() < 3)
                {
                    Account accountToUpdate = ReassignAccountOwner(associatedTerritory, updatedAcc);
                    List<Contact> newContactsToUpdate = 
                        ReassignContactsOwner(updatedAcc, accountToUpdate.OwnerId);
                            
                    List<Opportunity> newOppsToUpdate = 
                        ReassignOpenOpportunitiesOwner(updatedAcc, accountToUpdate.OwnerId);
                            
                    accountsToUpdate.add(accountToUpdate);
                    contactsToUpdate.addAll(newContactsToUpdate);
                    opportunitiesToUpdate.addAll(newOppsToUpdate);
                }
                else
                {
                    associatedTerritory.addError(ZIP_CODE_ERROR_MESSAGE);
                }
            }
        }
        
        if (!accountsToUpdate.isEmpty())
        {
            update accountsToUpdate;
        }

        if (!contactsToUpdate.isEmpty())
        {
            update contactsToUpdate;
        }

        if (!opportunitiesToUpdate.isEmpty())
        {
            update opportunitiesToUpdate;
        }

        if (!assignmentsHistoryToInsert.isEmpty())
        {
            insert assignmentsHistoryToInsert;
            assignmentsHistoryToInsert.clear();
        }
    }

    // Check if the zip code is already assigned to three sales representatives
    public void ProcessTerritoryUpsertion(List<Territory__c> territoriesToUpsert)
    {
        List<Territory__c> actualTerritories = 
        [
            SELECT Zip_Code__c 
            FROM Territory__c
        ];

        for (Territory__c territoryToUpsert : territoriesToUpsert)
        {
            Integer territoriesWithSameZipCodeSize = 0;
            for (Territory__c actualTerritory : actualTerritories)
            {
                if (territoryToUpsert.Zip_Code__c == actualTerritory.Zip_Code__c)
                    territoriesWithSameZipCodeSize++;
            }

            if (territoriesWithSameZipCodeSize == 3)
                territoryToUpsert.addError(ZIP_CODE_ERROR_MESSAGE);
        }
    } 

    // Save the dealers with new zip code in custom object AccountHistory records
    public void ProcessAccountHistory(List<Account> accountsToSave)
    {
        List<cstm_AccountHistory__c> zipCodeAutoDealersToArchive = new List<cstm_AccountHistory__c>();
        if (!accountsToSave.isEmpty())
        {
            String oldValue = null;
            List<cstm_AccountHistory__c> oldZipCodeAutoDealersHistory = 
            [
                SELECT Id, Accounts__c, OldValue__c, CreatedById
                FROM cstm_AccountHistory__c
                WHERE Field__c = 'BillingPostalCode'
                AND Accounts__c = :accountsToSave[0].Id
                ORDER BY CreatedDate ASC
            ];
            
            if (!oldZipCodeAutoDealersHistory.isEmpty())
            {
                oldValue = oldZipCodeAutoDealersHistory[0].OldValue__c;
            }

            cstm_AccountHistory__c newHistory = new cstm_AccountHistory__c
            (
                Accounts__c = accountsToSave[0].Id,
                OldValue__c = oldValue,
                Field__c = 'BillingPostalCode'
            );

            zipCodeAutoDealersToArchive.add(newHistory);
        }

        for (Integer i = 1; i < accountsToSave.size(); i++)
        {
            Account prevAcc = accountsToSave[i-1];
            Account actualAcc = accountsToSave[i];
            cstm_AccountHistory__c newHistory = new cstm_AccountHistory__c
            (
                Accounts__c = actualAcc.Id,
                OldValue__c = prevAcc.BillingPostalCode,
                Field__c = 'BillingPostalCode'
            );

            zipCodeAutoDealersToArchive.add(newHistory);
        }
        
        if (!zipCodeAutoDealersToArchive.isEmpty())
            insert zipCodeAutoDealersToArchive;
    }

    public List<Account> GetAutoDealersWithZipCodeChanged(
        Map<Id, Account> prevAccountsMap, 
        List<Account> updatedAccounts
    )
    {
        List<Account> mappedAccounts = new List<Account>();
        for (Account acc : updatedAccounts)
        {
            Account prevAcc = prevAccountsMap.get(acc.Id);
            if (prevAcc != null && prevAcc.BillingPostalCode != acc.BillingPostalCode)
                mappedAccounts.add(acc);
        }
        
        return mappedAccounts;
    }

    public List<Account> GetAutoDealersWithTerritoryOwnerChanged(
        Map<Id, Territory__c> oldTerritoriesMap, 
        List<Territory__c> newTerritories
    )
    {
        List<Account> accountsToUpdate = new List<Account>();
        Set<Id> oldOwnerIds = new Set<Id>();

        for (Territory__c newTerritory : newTerritories)
        {
            Territory__c oldTerritory = oldTerritoriesMap.get(newTerritory.Id);
            if (oldTerritory != null && newTerritory.Owner__c != oldTerritory.Owner__c)
                oldOwnerIds.add(oldTerritory.Owner__c);
        }

        List<Account> automobileDealersToUpdate = 
        [
            SELECT Id, OwnerId, BillingPostalCode
            FROM Account
            WHERE OwnerId IN :oldOwnerIds
        ];

        for (Account dealer : automobileDealersToUpdate)
        {
            for (Territory__c newTerritory : newTerritories)
            {
                if (
                    dealer.OwnerId == newTerritory.Owner__c && 
                    dealer.BillingPostalCode == newTerritory.Zip_Code__c
                ) 
                {
                    accountsToUpdate.add(dealer);
                    break;
                }
            }
        }

        return accountsToUpdate;
    }

    public void UpdateDataModelOwners(List<Account> mappedDealers)
    { 
        if (!System.isFuture())
        {
            Set<Id> mappedDealersId = new Set<Id>();
            for (Account acc : mappedDealers)
                mappedDealersId.add(acc.Id);

            UpdateDataModelOwnersByAccountsId(mappedDealersId);
        }
    }  
}