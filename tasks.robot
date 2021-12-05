# +
*** Settings ***
Documentation     Order Robot
...               This robot does the following:
...               Ask the user for the orders.csv URL
...               Load the RobotSpareBin Industries Inc order website
...               For each order:
...                 Enter order details
...                 Click preview
...                 Click submit
...                 Handle errors
...                 Scrape receipt html
...                 Screenshot robot picture
...                 Creates a PDF with receipt and picture
...               Creates a zip file containing all of the PDFs

Library           RPA.FileSystem
Library           RPA.Dialogs
Library           RPA.Browser.Selenium
Library           RPA.HTTP
Library           RPA.Tables
Library           RPA.PDF
Library           RPA.Archive
Library           RPA.Robocorp.Vault


# +
*** Variables ***
${ORDERS_CSV_FILE_NAME}=        ${CURDIR}${/}orders.csv

#Order entry page
#Buttons

${BUTTON_I_GUESS_SO}=           class:btn-danger
${BUTTON_PREVIEW}=              id:preview
${BUTTON_ORDER}=                id:order
${BUTTON_SHOW_MODEL_INFO}=      class:btn-secondary
${BUTTON_ORDER_ANOTHER_ROBOT}=  id:order-another

#Input fields
${INPUT_HEAD}=                  id:head
${INPUT_BODY}=                  body
${INPUT_LEGS}=                  xpath://div[3]/input
${INPUT_ADDRESS}=               id:address

${GLOBAL_RETRY_AMOUNT}=         10x
${GLOBAL_RETRY_INTERVAL}=       0.5s

${SUBMIT_PROOF_OF_SUCCESS}=     id:receipt
${ERROR_MESSAGE_BANNER}=        class:alert-danger

${RECEIPT}=                     id:receipt
${IMAGE_ROBOT}=                 id:robot-preview-image

${OUTPUT_FOLDER}=               ${CURDIR}${/}output
# -

*** Keywords ***
Collect URL From User
    Add text input    url    label='Report URL:'
    ${response}=    Run dialog
    [Return]    ${response.url}

*** Keywords ***
Open the robot order website
    [Arguments]    ${url}
    Open Available Browser  ${url}

*** Keywords ***
Close the annoying modal
    Click Button When Visible   ${BUTTON_I_GUESS_SO}

*** Keywords ***
Download Orders File
    [Arguments]    ${url}
    Download    ${url}    overwrite=True

*** Keywords ***
Get orders
    ${orders}=    Read table from CSV    ${ORDERS_CSV_FILE_NAME}
    [Return]    ${orders}

*** Keywords ***
Fill the form
    [Arguments]    ${row}
    
    #Extract row values
    ${orderNumber}=     Convert To Integer      ${row}[Order number]
    ${head}=            Convert To Integer      ${row}[Head]
    ${body}=            Convert To Integer      ${row}[Body]
    ${legs}=            Convert To Integer      ${row}[Legs]
    ${address}=         Convert To String       ${row}[Address]
    
    
    #Select Head type (uses index value specified in table) to select from drop-down
    Select From List By Index       ${INPUT_HEAD}       ${head}
    
    #Select body type (uses index value specified in table) to select correct radio button
    Select Radio Button             ${INPUT_BODY}       ${body}
    
    #Input text for Legs (uses index value specified in table)
    Input Text                      ${INPUT_LEGS}       ${legs}
    
    #Input text for Address (uses text value specified in table)
    Input Text                      ${INPUT_ADDRESS}    ${address}

*** Keywords ***
Preview the robot
    Click Button When Visible   ${BUTTON_PREVIEW}

# +
*** Keywords ***
Submit the order
    Wait Until Keyword Succeeds
    ...    ${GLOBAL_RETRY_AMOUNT}
    ...    ${GLOBAL_RETRY_INTERVAL}
    ...    Submit order once
   
    
# -

*** Keywords ***
Submit order once
    Click Button When Visible   ${BUTTON_ORDER}
    Element Should Not Be Visible    ${BUTTON_ORDER}
    #Element Should Not Be Visible    ${ERROR_MESSAGE_BANNER}
    #Element Should Be Visible    ${SUBMIT_PROOF_OF_SUCCESS}

*** Keywords ***
Go to order another robot
    Click Button When Visible   ${BUTTON_ORDER_ANOTHER_ROBOT}

*** Keywords ***
Store the receipt as a PDF file
    [Arguments]    ${orderNumber}
    
    Wait Until Element Is Visible    ${RECEIPT}
    ${receipt_html}=    Get Element Attribute    ${RECEIPT}    outerHTML
    Html To Pdf    ${receipt_html}    ${OUTPUT_FOLDER}${/}${orderNumber}.pdf
    [Return]    ${OUTPUT_FOLDER}${/}${orderNumber}.pdf

*** Keywords ***
Take a screenshot of the robot
    [Arguments]    ${orderNumber}
    Screenshot    ${IMAGE_ROBOT}    ${OUTPUT_FOLDER}${/}${orderNumber}.png
    [Return]    ${OUTPUT_FOLDER}${/}${orderNumber}.png

*** Keywords ***
Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    ${files}=    Create List
    ...    ${screenshot}
    Add Files To PDF    ${files}    ${pdf}  True

*** Keywords ***
Create a ZIP file of the receipts
    ${zip_file_name}=    Set Variable    ${OUTPUT_FOLDER}${/}Receipts.zip
    Archive Folder With Zip 
    ...    ${OUTPUT_FOLDER}
    ...    ${zip_file_name}
    ...    include=*.pdf

*** Keywords ***
Clear all files from output folder
    ${files}=    List Files In Directory    ${OUTPUT_FOLDER}
    FOR    ${file}  IN  @{FILES}
        Remove File    ${file}
    END

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    #Reference
    #https://robotsparebinindustries.com/orders.csv
    #https://robotsparebinindustries.com/#/robot-order

    ${secrets}=         Get Secret      secrets
    
    ${url_report}=      Collect URL From User
    Clear all files from output folder
    Log     Hi! All set. Generating receipts now.
    Download Orders File    ${url_report}
    Open the robot order website  ${secrets}[url]
    ${orders}=    Get orders
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill the form    ${row}
        Preview the robot
        Submit the order
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Go to order another robot
    END
    Create a ZIP file of the receipts
    [Teardown]  Close All Browsers
