public with sharing class VirginMoneyImport {

    public String MigrationButtonGrayedOut = 'true';
    public String getDataMigrationGrayedOut() {
        return MigrationButtonGrayedOut;
    }
    public void setDataMigrationGrayedOut(String vDisabled) {
        MigrationButtonGrayedOut = vDisabled;
    }
  
    public string fileName{get;set;} 
    public blob fileContent{get;set;}
    
    // VMG IDs in the CSV file that do not match the VMG ID field of any Contacts
    public list<fundRaiser> nonMatchingContacts = new list<fundRaiser>();
    public list<fundRaiser> getNonMatchingContacts() {
        return nonMatchingContacts;
    }
       
    // Contact records with VMG IDs matching some VMG ID in the CSV file
    // public list<Contact> matchedContacts{get;set;}
    public list<Contact> matchedContacts{get;set;}
    
    // Field Map = a list of maps
    public list<map<string,string>> fieldMap{get;set;}

    public string strOutputHeader;
    //Dynamic creation of Section Header
    public Component.Apex.SectionHeader getsecHead()
    {
        Component.Apex.SectionHeader sh = new Component.Apex.SectionHeader();
        // setstrOutputHeader('Set the Title');
        // sh.title = getstrOutputHeader();
        sh.title = this.strOutputHeader;
        return sh;
    }  


    // List of all fundraisers in the CSV file
    public list<fundRaiser> allFundRaisers = new list<fundRaiser>();
    // Donation Data will want to upload
    public List<Opportunity> DonationData = new List<Opportunity>();

    public PageReference MigrateData() {
        try {
            upsert DonationData;
        } catch (DmlException e) {
            // Process exception here
        }
        // Turn on disable flag on the Data Migration Button
        this.setDataMigrationGrayedOut('true');
        return null;
    }
    
    /**************************************************************
     * ReadFile: Fetch all Contact records containing a VMG ID that
     *           matches some (any) VMG ID in the CSV file.
     *
     * Output:   matchedContacts
     **************************************************************/
    public Pagereference ReadFile()
    {
        // Virgin Money Giver IDs
        // NOTE: vmgIds should be a set, because the same
        //       vmgId will likely be present in multiple
        //       rows. On finding a new vmgId we want to
        //       just add it to the set without worrying
        //       about creating duplicates. A set is the
        //       right data structure for that.
        set<String> vmgIds = new set<String>();

        // Two dimensional list to hold all of the CSV file data
        list<list<string>> csvData = new list<list<string>>();
        
        // Headers
        list<string> csvHeaders = new list<string>();
        
        fieldMap = new list<map<string,string>>();
        
        // Take amorphous data (blog data type) and parse it into a
        // table of Strings (data type: list<list<String>>)
        csvData = parseCSV(fileContent.toString(),false);
        
        // ****************
        // Build Field Map:
        //
        // Field Map is a list of maps, one for each row of the table.
        // (Recall that a map is itself a list, so a Field Map is a list of lsits)
        // The row map contains the elements of the row, each of which 
        // is paired with its corresponding column header. 
        //
        // NOTE: ideally this would have been done as a class but we want 
        //       to handle changes to the column headers 
        Boolean firstElement = true; 
        for(list<string> row : csvData) {
            if (firstElement) {
                // skip the first row, it only has headers
                firstElement = false;
                continue;
            }
            map<string,string> record = new map<string,string>();
            system.debug(row.size());
            // Step through the elements in the row, and for each element:
            // (1) Fetch the header for the element: csvData.get(0).get(i)
            // (2) Add the header/row element pair to the map: record.put(csvData.get(0).get(i),row.get(i)) 
            for(Integer i=0; i < row.size(); i++) {
                record.put(csvData.get(0).get(i),row.get(i));
                // system.debug('data: ' + csvData.get(0).get(i) + row.get(i));
            }
            
            fieldMap.add(record);
        }
        
        // Build a list of charity fundraiser IDs present in the table:
        // 
        // Step through the rows of the table, examining the map for each row.
        // With each map (record) fetch the value for the "charity fundraiser id".
        // Store the retrieved ID in the list: vmgIds.
        //
        // NOTE: the VMG IDs in the CSV files are 6 digit numbers with 
        //       *comma-separated* groups of 3 digits. We must remove these commas.
        //       Also, at this point, the VMG ID's are still enclosed in double quotes.
        //       We must also remove the double quotes. If we don't do this cleanup,
        //       we'll get numbers like this: "248,603" and they won't match the
        //       values stored in the Contact object.
        allFundRaisers.clear();
        for(map<string,string> record: fieldmap)
        {
            String strID;
            Integer numFR; // Number of Fundraisers
            if(record.get('charity fundraiser id') != null) {        
                // Remove commas
                strID = record.get('charity fundraiser id').replace(',','');
                // Remove double quotes and add to VMG ID list
                // Since this is a set, we can do an add for 
                // every ID in the CSV without fear of creating
                // duplicates.
                strID = strID.replace('"','');

                // number of  fundraisers so far
                numFR = vmgIds.size();
                
                // add new ID to set and see if it grows
                vmgIds.add(strID);
                
                // if the number of recorded IDs just grew
                // then add info for the new fundraiser to
                // allFundRaisers
                if (numFR < vmgIds.size()) {
                    fundRaiser fr = new fundRaiser();
                    fr.vmgID = strID;
                    fr.ForeName = record.get('fundraiser forename');
                    fr.SurName = record.get('fundraiser surname');
                    allFundRaisers.add(fr);
                }                
            }
        }
        
        // Retrieve Contact records with a VMG ID matching one of the IDs in the CSV file.
        matchedContacts = [SELECT Id, FirstName,LastName, Virgin_Money_Giving_Fundraiser_ID__c 
                           FROM Contact WHERE Virgin_Money_Giving_Fundraiser_ID__c IN :vmgIds];

        //************************************************************
        // TEST to see if we successfully matched all fundraisers 
        // in the CSV with a Contact. Based on this test, here's what we do:
        // Not all fundraisers matched: 
        //        Separate those that matched from those that didn't. 
        //        Display them in two separate lists.
        //        Data upload button will be grayed out.
        // All fundraisers matched:
        //        Display the matching fundraisers.
        //        Invite user to upload donation data.
        //************************************************************
        if(matchedContacts.size() != vmgIds.size()) {
            // Not All Fundraisers in CSV Have Corresponding Contact Object
            // Separate the matching fundraisers from the nonmatching fundraisers
            // 
            // NOTE: nonMatchingContacts is a public property. If we don't clear it here
            // it starts accumulating data across multiple invocations of the ReadFile method.
            nonMatchingContacts.clear();
            for (fundraiser fr: allFundRaisers) {
                String strID = fr.vmgID;
                Boolean foundOne = false;                
                for (Contact cnt : matchedContacts) {
                    if(strID == cnt.Virgin_Money_Giving_Fundraiser_ID__c) {
                        foundOne = true;
                    }
                }
                if (! foundOne) {
                    nonMatchingContacts.add(fr);
                }                
            }
        } else {
            // All fundraisers in the CSV have matching Contact Objects.
            //
            // Thus we can invite the user to upload all of the donation
            // data in the CSV file and store it in Opportunity records.
            // 
            // This is a list of the CSV fields we will extract from the
            // CSV to upload together with the corresponding field names
            // in the Opportunities object where each CSV field will be
            // stored:
            /*
                donation id                         Donation_ID__c
                donation date                       CloseDate
                donation type                       Donation_Type__c
                gross amount                        Gross_Amount__c
                card processing fee amount          Card_Processing_Fee_Amount__c
                card processing fee vat amount      Card_Processing_Fee_Vat_Amount__c
                transaction fee amount              Transaction_Fee_Amount__c
                transaction fee vat amount          Transaction_Fee_Vat_Amount__c
                gift aid amount                     Gift_Aid_Amount__c
                gift aid paid to charity status     Gift_Aid_Paid_to_Charity_Status__c
                charity donor id                    Donor_ID__c
             */
            DonationData.clear();
            for(map<string,string> record: fieldmap) {
            
                system.debug(record.get('donation id'));
                system.debug(record.get('donation date'));
                system.debug(record.get('donation type'));
                system.debug(record.get('gross amount'));
                system.debug(record.get('card processing fee amount'));
                system.debug(record.get('card processing fee vat amount'));
                system.debug(record.get('transaction fee amount'));
                system.debug(record.get('transaction fee vat amount'));
                system.debug(record.get('gift aid amount'));
                system.debug(record.get('gift aid paid to charity status'));
                system.debug(record.get('charity donor id'));
            
                Opportunity op = new Opportunity();
                // Can't do upset with Stage and Opportunity Name fields,
                // but this data is not in the CSV, so just assign as follows:
                // For Opportunity Name: use Donor Name
                // For Opportunity State: use "Closed Won"
                
                // op.Stage = 1;
                
                op.Donation_ID__c = record.get('donation id');
                // op.CloseDate = Date.parse(record.get('donation date'));
                op.CloseDate = Date.parse('12/27/2009');
                op.Donation_Type__c = record.get('donation type');
                op.Gross_Amount__c = Decimal.valueOf(record.get('gross amount'));
                op.Card_Processing_Fee_Amount__c = 
                    Decimal.valueOf(record.get('card processing fee amount'));
                op.Card_Processing_Fee_Vat_Amount__c = 
                    Decimal.valueOf(record.get('card processing fee vat amount'));
                op.Transaction_Fee_Amount__c = 
                    Decimal.valueOf(record.get('transaction fee amount'));
                op.Transaction_Fee_Vat_Amount__c = 
                    Decimal.valueOf(record.get('transaction fee vat amount'));
                // op.Gift_Aid_Amount__c = 
                //    Decimal.valueOf(record.get('gift aid amount'));
                op.Gift_Aid_Paid_to_Charity_Status__c = record.get('gift aid paid to charity status');
                op.Donor_ID__c = record.get('charity donor id');
                // Don't have an Opportunity Name. Just use the Donor's Name.
                op.Name = op.Donor_ID__c;
                DonationData.add(op);
            }
            // Turn off disable flag on the Data Migration Button
            this.setDataMigrationGrayedOut('false');            
        }
        return null;
    }

    /********************************************************************
     * parsecsv: Breaks CSV file down into a table (a list of lines or 
     *           2-dimensional list of Strings: list<list<String>>)
     *
     * This code was borrowed from: http://wiki.developerforce.com/page/Code_Samples#Parse_a_CSV_with_APEX 
     ********************************************************************/
    public static List<List<String>> parseCSV(String contents,Boolean skipHeaders) {
        List<List<String>> allFields = new List<List<String>>();
    
        // replace instances where a double quote begins a field containing a comma
        // in this case you get a double quote followed by a doubled double quote
        // do this for beginning and end of a field
        contents = contents.replaceAll(',"""',',"DBLQT').replaceall('""",','DBLQT",');
        // now replace all remaining double quotes - we do this so that we can reconstruct
        // fields with commas inside assuming they begin and end with a double quote
        contents = contents.replaceAll('""','DBLQT');

        // Identify Rows of Spreadsheet: split on newline
        // NOTE: we are not attempting to handle fields with a 
        //       newline inside of them
        List<String> lines = new List<String>();
        try {
            lines = contents.split('\r\n');
        } catch (System.ListException e) {
            System.debug('Limits exceeded?' + e.getMessage());
        }
        
        // Identify Fields: iterate through lines, breaking each
        //                  line into spreadsheet cells (i.e. columns)
        Integer num = 0;
        for(String line : lines) {
            // check for blank CSV lines (only commas)
            if (line.replaceAll(',','').trim().length() == 0) break;
            
            List<String> fields = line.split(',');  
            List<String> cleanFields = new List<String>();
            String compositeField;
            Boolean makeCompositeField = false;
            for(String field : fields) {
                if (field.startsWith('"') && field.endsWith('"')) {
                    cleanFields.add(field.replaceAll('DBLQT','"'));
                } else if (field.startsWith('"')) {
                    makeCompositeField = true;
                    compositeField = field;
                } else if (field.endsWith('"')) {
                    compositeField += ',' + field;
                    cleanFields.add(compositeField.replaceAll('DBLQT','"'));
                    makeCompositeField = false;
                } else if (makeCompositeField) {
                    compositeField +=  ',' + field;
                } else {
                    cleanFields.add(field.replaceAll('DBLQT','"'));
                }
            }
            // Another line (row) of parsed data is ready
            // Add the current line of fields to the table
            allFields.add(cleanFields);
        }
        if (skipHeaders) allFields.remove(0);
        
        // Return the complete table
        return allFields;       
    }
}