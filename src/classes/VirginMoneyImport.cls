public with sharing class VirginMoneyImport {

    public string fileName{get;set;} 
    public blob fileContent{get;set;}
    
    public list<list<string>> csvData{get;set;}
    public list<string> csvHeaders{get;set;}
    public set<String> vmgIds{get;set;}
    public list<map<string,string>> fieldMap{get;set;}
    
    public list<Contact> matchedContacts{get;set;}
    
    public Pagereference ReadFile()
    {
        vmgIds = new set<String>();
        fieldMap = new list<map<string,string>>();
         
        //csvHeaders = parseCSV(fileContent.toString(),false).get(0);
        csvData = parseCSV(fileContent.toString(),false);
        
        //map each row from the parsed csv to a list of records, each containing a map of field names and values
        //ideally this would have been done as a class but we want to handle column headers changing
        for(list<string> row : csvData)
        {
            map<string,string> record = new map<string,string>();
            system.debug(row.size());
            for(Integer i=0; i < row.size(); i++)
            {
                record.put(csvData.get(0).get(i),row.get(i));
                system.debug('data: ' + csvData.get(0).get(i) + row.get(i));
            }
            
            fieldMap.add(record);
        }
        
        
        for(map<string,string> record: fieldmap)
        {
            if(record.get('charity fundraiser id') != null)
                vmgIds.add(record.get('charity fundraiser id').replace(',',''));
        }
        
        matchedContacts = [SELECT Id, FirstName,LastName FROM Contact WHERE Virgin_Money_Giving_Fundraiser_ID__c IN :vmgIds];
        return null;
    }

    //code from http://wiki.developerforce.com/page/Code_Samples#Parse_a_CSV_with_APEX which parses CSV to a list<list<String>>
    public static List<List<String>> parseCSV(String contents,Boolean skipHeaders) {
        List<List<String>> allFields = new List<List<String>>();
    
        // replace instances where a double quote begins a field containing a comma
        // in this case you get a double quote followed by a doubled double quote
        // do this for beginning and end of a field
        contents = contents.replaceAll(',"""',',"DBLQT').replaceall('""",','DBLQT",');
        // now replace all remaining double quotes - we do this so that we can reconstruct
        // fields with commas inside assuming they begin and end with a double quote
        contents = contents.replaceAll('""','DBLQT');
        // we are not attempting to handle fields with a newline inside of them
        // so, split on newline to get the spreadsheet rows
        List<String> lines = new List<String>();
        try {
            lines = contents.split('\r\n');
        } catch (System.ListException e) {
            System.debug('Limits exceeded?' + e.getMessage());
        }
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
            
            allFields.add(cleanFields);
        }
        if (skipHeaders) allFields.remove(0);
        return allFields;       
    }
}