public class AutomobileDealerService
{
    private static List<Assignment_History__c> assignmentsHistoryToInsert { get; private set; }
    private static List<Assignment_History__c> oldAssigmentHistory { get; private set; }
    private static List<cstm_AccountHistory__c> zipCodeAutoDealersToArchive { get; private set; }
    private static List<cstm_AccountHistory__c> oldZipCodeAutoDealersHistory { get; private set; }
    private static List<Territory__c> territories { get; private set; }
    private static List<Contact> dealersEmployees { get; private set; }
    private static List<Opportunity> dealerOpportunities { get; private set; }
    private static List<Account> automobileDealers { get; private set; }
    
    private static Territory__c GetTerritoryByZipCode(String zipCode)
    {
        List<Territory__c> possibleTerritories = new List<Territory__c>();
        for (Territory__c territory : territories)
        {
            if (territory.Zip_Code__c == zipCode)
                possibleTerritories.add(territory);
        }

        Integer territoriesSize = possibleTerritories.size();
        if (territoriesSize > 0)
        {
            // use a random function to select one of the assigned sales representatives
            Integer randomInt = Math.floor(Math.random()).intValue();
            Integer randomIndex = Math.Mod(randomInt, territoriesSize);
            return possibleTerritories[randomIndex];
        }

        return null;
    }

    // Three sales representatives at most can be assigned to a single zip code.
    private static Boolean IsZipCodeAssignable(String zipCode)
    {
        Integer count = 0;
        for (Territory__c territory : territories)
        {
            if (territory.Zip_Code__c == zipCode)
                count ++;
        }

        return count < 3;
    }

    private static cstm_AccountHistory__c GetLastAutoDealerHistory(Id dealerAccountId)
    {
        cstm_AccountHistory__c lastHistory = null;
        for (cstm_AccountHistory__c history : oldZipCodeAutoDealersHistory)
        {
            if (history.Accounts__c == dealerAccountId)
                lastHistory = history;
        }

        return lastHistory;
    } 

    private static Id GetLastTerritoryId(Id territoryId)
    {
        Id lastTerritoryId = null;
        for (Assignment_History__c history : oldAssigmentHistory)
        {
            if (history.New_Territory__c == territoryId)
                lastTerritoryId = history.Previous_Territory__c;
        }

        return lastTerritoryId;
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
    private static Account ReassignAccountOwner(Account dealerAccount)
    {
        Territory__c associatedTerritory = GetTerritoryByZipCode(dealerAccount.BillingPostalCode);
        Boolean isAssignable = IsZipCodeAssignable(dealerAccount.BillingPostalCode);
        
        if (associatedTerritory != null && isAssignable)
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
        else if (!isAssignable)
        {
            associatedTerritory.addError('The zip code is already assigned to three sales representatives');
        }

        return null;
    }

    // Change the Owner field of all the Account’s Contacts to the same sales rep
    private static List<Contact> ReassignContactsOwner(Account dealerAccount, Id newOwnerId)
    {
        List<Contact> accountEmployees = new List<Contact>();
        for (Contact employee : dealersEmployees)
        {
            if (employee.AccountId == dealerAccount.Id)
                accountEmployees.add(employee);
        }

        for (Contact employeesToUpdate : accountEmployees)
        {
            employeesToUpdate.OwnerId = newOwnerId;
        }

        return accountEmployees;
    }

    // Change the Owner field of all the Account’s Open Opportunities to the same sales rep
    private static List<Opportunity> ReassignOpenOpportunitiesOwner(Account dealerAccount, Id newOwnerId)
    {
        List<Opportunity> dealerOpenOpportunities = new List<Opportunity>();
        for (Opportunity opp : dealerOpportunities)
        {
            if (opp.AccountId == dealerAccount.Id && opp.IsClosed == false)
                dealerOpenOpportunities.add(opp);
        }

        for (Opportunity opportunitiesToUpdate : dealerOpenOpportunities)
        {
            opportunitiesToUpdate.OwnerId = newOwnerId;
        }

        return dealerOpenOpportunities;
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

        List<Contact> contactsToUpdate = new List<Contact>();
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        List<Account> accountsToUpdate = new List<Account>();

        for (Account updatedAcc : updatedAccounts)
        {
            Account accountToUpdate = ReassignAccountOwner(updatedAcc);
            if (accountToUpdate != null)
            {
                List<Contact> newContactsToUpdate = 
                    ReassignContactsOwner(updatedAcc, accountToUpdate.OwnerId);
                    
                List<Opportunity> newOppsToUpdate = 
                    ReassignOpenOpportunitiesOwner(updatedAcc, accountToUpdate.OwnerId);
                    
                accountsToUpdate.add(accountToUpdate);
                contactsToUpdate.addAll(newContactsToUpdate);
                opportunitiesToUpdate.addAll(newOppsToUpdate);
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

    public AutomobileDealerService()
    {
        territories = 
        [
            SELECT Id, Zip_Code__c, Owner__c
            FROM Territory__c
        ];

        dealersEmployees = 
        [
            SELECT Id, AccountId 
            FROM Contact
        ];

        dealerOpportunities = 
        [
            SELECT Id, OwnerId, AccountId, IsClosed
            FROM Opportunity
        ];

        automobileDealers = 
        [
            SELECT Id, OwnerId, BillingPostalCode
            FROM Account
        ];

        oldZipCodeAutoDealersHistory =
        [
            SELECT Accounts__c, OldValue__c, Field__c, CreatedById
            FROM cstm_AccountHistory__c
        ];

        oldAssigmentHistory =
        [
            SELECT Previous_Territory__c, New_Territory__c
            FROM Assignment_History__c
        ];
        
        assignmentsHistoryToInsert = new List<Assignment_History__c>();
        zipCodeAutoDealersToArchive = new List<cstm_AccountHistory__c>();
    }

    // Save the dealers with new zip code in custom object AccountHistory records
    public void ProcessAccountHistory(List<Account> accountsToSave)
    {
        if (!accountsToSave.isEmpty())
        {
            String oldValue = null;
            if (!oldZipCodeAutoDealersHistory.isEmpty())
            {
                Integer lastHistoryIndex = oldZipCodeAutoDealersHistory.size() - 1;
                cstm_AccountHistory__c lastHistory = oldZipCodeAutoDealersHistory[lastHistoryIndex];
                oldValue = lastHistory.OldValue__c;
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
        {
            insert zipCodeAutoDealersToArchive;
        }
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
            if (prevAcc.BillingPostalCode != acc.BillingPostalCode)
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
        for (Territory__c updTerritory : newTerritories)
        {
            Territory__c oldTerritory = oldTerritoriesMap.get(updTerritory.Id);
            if (updTerritory.Owner__c != oldTerritory.Owner__c)
            {
                for (Account acc : automobileDealers)
                {
                    if (
                        acc.OwnerId == oldTerritory.Owner__c && 
                        acc.BillingPostalCode == updTerritory.Zip_Code__c
                    )
                        accountsToUpdate.add(acc);
                }
            }
        }

        return accountsToUpdate;
    }

    public void UpdateDataModelOwners(List<Account> mappedDealers)
    { 
        if(!System.isFuture())
        {
            List<Account> retrievedDealers = 
            [
                SELECT Id
                FROM Account
                WHERE Id IN :mappedDealers
            ];
        
            Set<Id> mappedDealersId = new Map<Id, Account>(retrievedDealers).keySet();
            UpdateDataModelOwnersByAccountsId(mappedDealersId);
        }
    }
}