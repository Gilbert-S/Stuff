# https = //docs.microsoft.com/en-us/microsoftteams/platform/task-modules-and-cards/cards/cards-reference#office-365-connector-card
#
# Office 365 connector card
# Supported in Teams, not in Bot Framework.
#
# The Office 365 Connector card provides a flexible layout with multiple sections, fields, images, and actions. This card encapsulates a connector card so that it can be used by bots. See the notes section for differences between connector cards and the O365 card.

$connectorUri = "https://outlook.office.com/webhook/7e121d28-829a-4f56-aba4-4b1a994416ab@8e656664-5f36-4a5b-954c-c5405fd29206/IncomingWebhook/6c8dcf05dbbb46648156b14681d154d3/8e188e18-8521-4dc3-bde2-477f99c83575"


$Application = "CCP_CC_DTS-Test-App_1-0_C_x86_1-0_CCP0001"

$TemplateMessageCardIntegrationSuccess = [PSCustomObject][Ordered]@{

    "@type" = "MessageCard"
    "@context" =  "http://schema.org/extensions"
    "title" =  "[CUSTOMER] - Runbook"
    "themeColor" = "0078D7"
    "summary" = "Application imported"
    "sections" =  @(
        @{
            "text" =  "<font color='green'><b>&#10003;</b></font> Application Import <font color='green'><b>successfull</b></font>.<br/><at>Test</at> <at>@Test</at>"
            "markdown" = $false
        },
        @{
            "markdown" = $false
            "facts" =  @(
                @{
                    "name" =  "Application:"
                    "value" =  $Application
                },
                @{
                    "name" =  "Site:"
                    "value" =  "GAS"
                },
                @{
                    "name" =  "Testclients:"
                    "value" =  "2 Clients assigned"
                },
                @{
                    "name" =  "DTS Job ID:"
                    "value" =  "877"
                }
            )
        }
    )

}

$body = ConvertTo-Json $JSON -Depth 100
Invoke-RestMethod -Uri $connectorUri -Method Post -Body $body -ContentType 'application/json'
