// Декодировать данные
function urldecode(url) {
  return decodeURIComponent(url.replace(/\+/g, " "));
}

// Здесь устанавливать какой параметр в какую колонку ставить
const replace = {
  test: { executor: 1, who: 2, reason: 4, date: 3 },
};

function doGet(e) {
  const param = e.parameter;
  const response = {};

  if (
    param.type == undefined ||
    param.date == undefined ||
    param.executor == undefined ||
    param.who == undefined ||
    param.reason == undefined ||
    param.param1 == undefined ||
    param.param2 == undefined
  ) {
    response.error = true;
    response.errortext = "Request is undefined";
    return ContentService.createTextOutput(JSON.stringify(response));
  }

  param.param1 = urldecode(param.param1);
  param.param2 = urldecode(param.param2);
  param.reason = urldecode(param.reason);

  const ss = SpreadsheetApp.openById("TABLE ID");
  SpreadsheetApp.setActiveSpreadsheet(ss);
  switch (param.type) {
    case "test":
      SpreadsheetApp.setActiveSheet(ss.getSheetByName("test"));
      break;
    default:
      response.error = true;
      response.errortext = "Type is not defined";
      return ContentService.createTextOutput(JSON.stringify(response));
  }

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const lastRow = sheet.getLastRow() + 1;

  for (const key in replace[param.type]) {
    if (param[key] == undefined) {
      param[key] = "";
    }
  
    sheet.getRange(lastRow, replace[param.type][key]).setValue(param[key]);
  }

  response.param = param.param2;
  response.success = true;
  response.response = "200 OK";
  response.who = param.who;
  response.executor = param.executor;
  response.date = param.date;
  response.reason = param.reason;
  response.param1 = param.param1;
  response.param2 = param.param2;
  return ContentService.createTextOutput(JSON.stringify(response));
}
