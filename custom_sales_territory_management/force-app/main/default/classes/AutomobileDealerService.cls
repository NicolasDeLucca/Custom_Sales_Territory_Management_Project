public class AutomobileDealerService
{
    private List<AccountHistory> ZipCodeAccountsHistory { get; private set; }
    private List<Territory__c> Territories { get; private set; }
    private List<Contact> dealersEmployees { get; private set; }
    private List<Opportunity> dealerOpportunities { get; private set; }
    private List<Assignment_History__c> assignmentsHistory { get; set; }
    
    private Territory__c GetTerritoryByZipCode(String zipCode)
    {
        List<Territory__c> possibleTerritories = new List<Territory__c>();
        for (Territory__c territory : this.Territories)
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
    private Boolean IsZipCodeAssignable(String zipCode)
    {
        Integer count = 0;
        for (Territory__c territory : this.Territories)
        {
            if (territory.Zip_Code__c == zipCode)
                count++;
        }

        return count <= 3;
    }

    private Territory__c SearchTerritory(String zipCode, Id ownerId)
    {
        for (Territory__c territory : this.Territories)
        {
            if (territory.Zip_Code__c == zipCode && territory.Owner__c == ownerId)
                return territory;
        }

        return null;
    }

    private AccountHistory GetLastAutoDealerHistory(Id dealerAccountId)
    {
        AccountHistory lastHistory = null;
        for (AccountHistory history : this.ZipCodeAccountsHistory)
        {
            if (history.AccountId == dealerAccountId)
                lastHistory = history;
        }

        return lastHistory;
    } 

    private void StoreAssignmentHistory(
        Id prevOwner, 
        Id newOwner, 
        Id prevTerritoryId, 
        Id newTerritoryId, 
        Id accountId, 
        Id createdById
    )
    {
        Assignment_History__c newAssignment = new Assignment_History__c
        (
            Previous_Owner__c = prevOwner,
            New_Owner__c = newOwner,
            Previous_Territory__c = prevTerritoryId,
            New_Territory__c = newTerritoryId,
            Account__c = accountId,
            Changed_By__c = createdById
        );

        this.assignmentsHistory.add(newAssignment);
    }

    public AutomobileDealerService()
    {
        this.ZipCodeAccountsHistory = 
        [
            SELECT AccountId, Field, CreatedById
            FROM AccountHistory
            WHERE Field = 'BillingPostalCode'
        ];

        this.Territories = 
        [
            SELECT Id, Zip_Code__c, Owner__c
            FROM Territory__c
        ];

        this.dealersEmployees = 
        [
            SELECT Id, AccountId 
            FROM Contact
        ];

        this.dealerOpportunities = 
        [
            SELECT Id, OwnerId
            FROM Opportunity
        ];

        this.assignmentsHistory = new List<Assignment_History__c>();
    }
    
    // Verifies if some Automobile Dealer's Zip Code has ever changed
    private Boolean HasZipCodeChanged(Id dealerId)
    {
        for (AccountHistory history : this.ZipCodeAccountsHistory)
        {
            if (history.AccountId == dealerId)
                return true;
        }

        return false;
    }

    // Change the Account Owner to the sales representative assigned to the new zip code
    private Account ReassignAccountOwner(Account dealerAccount)
    {
        Territory__c associatedTerritory = this.GetTerritoryByZipCode(dealerAccount.BillingPostalCode);
        Boolean isAssignable = this.IsZipCodeAssignable(dealerAccount.BillingPostalCode);

        if (associatedTerritory != null && isAssignable)
        {
            AccountHistory prevAutoDealerHistory = this.GetLastAutoDealerHistory(dealerAccount.Id);
            
            Territory__c prevTerritory = this.SearchTerritory(
                prevAutoDealerHistory.Field, 
                dealerAccount.OwnerId
            );

            this.StoreAssignmentHistory(
                dealerAccount.OwnerId, 
                associatedTerritory.Owner__c,
                prevTerritory.Id,
                associatedTerritory.Id,
                dealerAccount.Id,
                prevAutoDealerHistory.CreatedById
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
    private List<Contact> ReassignContactsOwner(Account dealerAccount, Id newOwnerId)
    {
        List<Contact> accountEmployees = new List<Contact>();
        for (Contact employee : this.dealersEmployees)
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
    private List<Opportunity> ReassignOpenOpportunitiesOwner(Account dealerAccount, Id newOwnerId)
    {
        List<Opportunity> accountOpportunities = new List<Opportunity>();
        for (Opportunity opp : this.dealerOpportunities)
        {
            if (opp.AccountId == dealerAccount.Id && opp.IsClosed == false)
                accountOpportunities.add(opp);
        }

        for (Opportunity opportunitiesToUpdate : accountOpportunities)
        {
            opportunitiesToUpdate.OwnerId = newOwnerId;
        }

        return accountOpportunities;
    }

    public void UpdateDataModelOwners(List<Account> updatedAccounts)
    {
        List<Contact> contactsToUpdate = new List<Contact>();
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        List<Account> accountsToUpdate = new List<Account>();

        for (Account updatedAcc : updatedAccounts)
        {
            if (!this.HasZipCodeChanged(updatedAcc.Id))
            {
                Account accountToUpdate = this.ReassignAccountOwner(updatedAcc);
                if (accountToUpdate != null)
                {
                    List<Contact> newContactsToUpdate = 
                        this.ReassignContactsOwner(updatedAcc, accountToUpdate.OwnerId);
                    
                    List<Opportunity> newOppsToUpdate = 
                        this.ReassignOpenOpportunitiesOwner(updatedAcc, accountToUpdate.OwnerId);
                    
                    accountsToUpdate.add(accountToUpdate);
                    contactsToUpdate.addAll(newContactsToUpdate);
                    opportunitiesToUpdate.addAll(newOppsToUpdate);
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

        if (!this.assignmentsHistory.isEmpty())
        {
            insert this.assignmentsHistory;
        }
    }
}