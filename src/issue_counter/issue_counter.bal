import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/config;
import ballerina/task;

string spreadsheet_access_token = config:getAsString("SPREADSHEET_ACCESS_TOKEN");
string github_access_token = config:getAsString("GITHUB_ACCESS_TOKEN");
string github_username = config:getAsString("GITHUB_USERNAME");
string[] repos = ["ballerina", "testing"];
string[] labels = ["Type/Bug", "Severity/Blocker"];

 http:Client clientEPForSpreadsheet = new("https://sheets.googleapis.com/");
json spreadsheetJSONPayload = { "properties": { "title": "Issues" } };
http:Request request = new;
string spreadSheetPath = "/v4/spreadsheets";
string spreadsheetId = "";

task:TimerConfiguration timerConfiguration = {
    intervalInMillis: 1000,
    initialDelayInMillis: 300,
    noOfRecurrences: 2
};
listener task:Listener timer = new(timerConfiguration);

service timerService on timer {
    resource function onTrigger() {
        callWeatherService();
    }
}

function callWeatherService(){
    createspreadSheet();
    createSheet();
    getIssuesCountAndAddInSpreadSheet();
}

function createspreadSheet() {
    spreadsheet_access_token = "Bearer " + spreadsheet_access_token;
    request.addHeader("Authorization", spreadsheet_access_token);
    request.setJsonPayload(spreadsheetJSONPayload);    
    var spreadsheetResopnse = clientEPForSpreadsheet->post(spreadSheetPath, request);
    if (spreadsheetResopnse is http:Response) {
        var payload = spreadsheetResopnse.getJsonPayload();
        if (payload is json) {
            spreadsheetId = <@untained> payload.spreadsheetId.toString();
        } else {
            log:printError(<string>payload.detail()["message"]);
        }
    } else {
        log:printError(<string>spreadsheetResopnse.detail()["message"]);
    }
}
function createSheet() {
    spreadsheet_access_token = "Bearer " + spreadsheet_access_token;
    request.addHeader("Authorization", spreadsheet_access_token);
    json sheetJSONPayload = {"requests" : [{"addSheet":{"properties":{"title" : "IssueRecords"}}}]};
    request.setJsonPayload(sheetJSONPayload);
    string addSheetPath = spreadSheetPath + "/" + spreadsheetId + ":batchUpdate"; 
    int sheetId;
    var spreadsheetResopnse = clientEPForSpreadsheet->post(<@untainted> addSheetPath, request);  
    if (spreadsheetResopnse is error) {
        log:printError(<string>spreadsheetResopnse.detail()["message"]);
    } 
    string setValuePath = spreadSheetPath + "/" + spreadsheetId + "/values/IssueRecords!A1:C1?valueInputOption=RAW";
    json[][] values = [["reop", "Total no of issue", "Total no of issue with label combination"]];
    json jsonPayload = {
        "values": values
    };
    request.setJsonPayload(jsonPayload);
    spreadsheetResopnse = clientEPForSpreadsheet->put(<@untainted> setValuePath, request);
    if (spreadsheetResopnse is error) {
        log:printError(<string>spreadsheetResopnse.detail()["message"]);
    }
}

function getIssuesCountAndAddInSpreadSheet() {
    http:Client clientEP = new("https://api.github.com");
    http:Request req = new;
    req = new;
    req.addHeader("access_token", github_access_token);
    spreadsheet_access_token = "Bearer " + spreadsheet_access_token;
    request.addHeader("Authorization", spreadsheet_access_token);

    string label= "&labels=";
    json[] val = [];
    json[][] values =[];
    foreach var value in labels {
        label = label + value + "&&";
    }
    int i = 2;
    label = label.substring(0, label.length() -2);
    foreach var repo in repos {
        string path = "/repos/" + github_username + "/" + repo + "/issues?state=all";
        var resp = clientEP->get(path, req);
        val[0] = repo; 
        if (resp is http:Response) {
            var payload = resp.getJsonPayload();
            if (payload is json) {
                json[] issue = <json[]> payload;
                val[1] = issue.length(); 
            } else {
                log:printError(<string>payload.detail()["message"]);
            }
        } else {
            log:printError(<string>resp.detail()["message"]);
        }  

        var res = clientEP->get(path + label, req);
        if (res is http:Response) {
            var payload = res.getJsonPayload();
            if (payload is json) {
                json[] issue = <json[]> payload;
                val[2] = issue.length(); 
            } else {
                log:printError(<string>payload.detail()["message"]);
            }
        } else {
            log:printError(<string>res.detail()["message"]);
        }
        string setValuePath = spreadSheetPath + "/" + spreadsheetId + "/values/IssueRecords!A" + i.toString() + ":C" + i.toString() + 
        "?valueInputOption=RAW";
        values[0] = val;
        json jsonPayload = {
            "values": values
        };
        request.setJsonPayload(<@untainted> jsonPayload);
        var spreadsheetResopnse = clientEPForSpreadsheet->put(<@untainted> setValuePath, request);
        if (spreadsheetResopnse is error) {
            log:printError(<string>spreadsheetResopnse.detail()["message"]);
        } else {
            io:println(spreadsheetResopnse);
        }
        i = i + 1;    
    }
}
