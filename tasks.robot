*** Settings ***
Documentation   Template robot main suite.
Library         RPA.Browser.Selenium
Library         RPA.HTTP
Library         RPA.Tables
Library         RPA.PDF
Library         RPA.Archive
Library         RPA.Dialogs
Library         RPA.Robocloud.Secrets


*** Variables ***
${CSV_FILE_URL}=             https://robotsparebinindustries.com/orders.csv
${GLOBAL_RETRY_AMOUNT}=      7x
${GLOBAL_RETRY_INTERVAL}=    1s

*** Keywords ***
Get Credentials from Vault and Open the robot order website
    ${url}=        Get Secret    credentials
    Open Available Browser       ${url}[robotsparebinURL]
    Maximize Browser Window

*** Keywords ***
Get CSVFile from User
    Create Form     CSVFileURL
    Add Text Input    URL    url
    ${response}    Request Response
    [Return]    ${response["url"]}     

*** Keywords ***
Get orders
    ${CSV_FILE_URL}=        Get CSVFile from User
    Download        ${CSV_FILE_URL}             overwrite=True
    ${orders}=         Read Table From Csv       orders.csv        dialect=excel           header=True
    FOR     ${order}    IN    @{orders}
        Log    ${order}
    END
    [Return]        ${orders}

*** Keywords ***
Close the annoying modal
    Click Button        OK

*** Keywords ***
Fill the Order Form
    [Arguments]     ${row}
    ${head}=    Convert To Integer      ${row}[Head]
    ${body}=    Convert To Integer      ${row}[Body]
    ${legs}=    Convert To Integer      ${row}[Legs]
    ${shipping_address}=    Convert To String           ${row}[Address]
    Select From List By Value       id:head         ${head}
    Click Element       id:id-body-${body}
    Input Text          id:address          ${shipping_address}
    Input Text          xpath:/html/body/div/div/div[1]/div/div[1]/form/div[3]/input            ${legs}


*** Keywords ***    
Preview the robot
    Click Element       id:preview
    Wait Until Element Is Visible       id:robot-preview  

*** Keywords ***
Submit the Order and check success
    Click Element       id:order
    Element Should Be Visible           id:order-completion

*** Keywords ***
Submit Order
    Wait Until Keyword Succeeds         ${GLOBAL_RETRY_AMOUNT}       ${GLOBAL_RETRY_INTERVAL}         Submit the Order and check success 

*** Keywords ***
Save Receipt as PDF
    [Arguments]         ${OrderNo}
    Wait Until Element Is Visible       id:order-completion
    ${receipt}=         Get Element Attribute       id:order-completion         outerHTML
    Html To Pdf         ${receipt}          ${CURDIR}${/}output${/}receipts${/}${OrderNo}.pdf
    [Return]        ${CURDIR}${/}output${/}receipts${/}${OrderNo}.pdf

*** Keywords ***
Screenshot of the Robot Image
    [Arguments]         ${OrderNo}
    Screenshot          id:robot-preview          ${CURDIR}${/}output${/}${OrderNo}.png
    [Return]        ${CURDIR}${/}output${/}${OrderNo}.png

*** Keywords ***
Merge PDF with Screenshot
    [Arguments]     ${ss}    ${pdf}
    Open Pdf        ${pdf}
    Add Watermark Image To Pdf      ${ss}       ${pdf}
    Close Pdf       ${pdf}

*** Keywords ***
Go to order another robot
    Click Element       id:order-another  

*** Keywords ***
Create a ZIP file of the receipts
    Archive Folder With Zip    ${CURDIR}${/}output${/}receipts    ${CURDIR}${/}output${/}Receipts.zip   

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Get Credentials from Vault and Open the robot order website
    ${orders}=  Get orders
    FOR     ${row}      IN      @{orders}
        Close the annoying modal
        Fill the Order Form     ${row}
        Preview the robot
        Submit Order
        ${pdf}=     Save Receipt as PDF     ${row}[Order number]
        ${screenshot}=      Screenshot of the Robot Image          ${row}[Order number]
        Merge PDF with Screenshot       ${screenshot}           ${pdf}
        Go to order another robot
    END
    Create a ZIP file of the receipts
    [Teardown]    Close Browser


