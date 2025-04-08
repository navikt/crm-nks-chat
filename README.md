# CRM-NKS-CHAT

[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://github.com/navikt/crm-shared-template/blob/master/LICENSE)

Repository containing core components for the nks-chat functionality

## Dependencies

This package is dependant on the following packages

-   [crm-platform-base](https://github.com/navikt/crm-platform-base)
-   [crm-platform-integration](https://github.com/navikt/crm-platform-integration)
-   [crm-nks-base-components](https://github.com/navikt/crm-nks-base-components)
-   [crm-journal-utilities](https://github.com/navikt/crm-journal-utilities)
-   [crm-shared-user-notification](https://github.com/navikt/crm-shared-user-notification)
-   [crm-shared-flowComponents](https://github.com/navikt/crm-shared-flowComponents)
-   [crm-henvendelse](https://github.com/navikt/crm-henvendelse)

## Installation

1. Install [npm](https://nodejs.org/en/download/)
1. Install [Salesforce DX CLI](https://developer.salesforce.com/tools/sfdxcli)
    - Alternative: `npm install sfdx-cli --global`
1. Clone this repository ([GitHub Desktop](https://desktop.github.com) is recommended for non-developers)
1. Run `npm install` from the project root folder
1. Install [SSDX](https://github.com/navikt/ssdx)
    - **Non-developers may stop after this step**
1. Install [VS Code](https://code.visualstudio.com) (recommended)
    - Install [Salesforce Extension Pack](https://marketplace.visualstudio.com/items?itemName=salesforce.salesforcedx-vscode)
    - **Install recommended plugins!** A notification should appear when opening VS Code. It will prompt you to install recommended plugins.
1. Install [AdoptOpenJDK](https://adoptopenjdk.net) (only version 8 or 11)
1. Open VS Code settings and search for `salesforcedx-vscode-apex`
1. Under `Java Home`, add the following:
    - macOS: `/Library/Java/JavaVirtualMachines/adoptopenjdk-[VERSION_NUMBER].jdk/Contents/Home`
    - Windows: `C:\\Program Files\\AdoptOpenJDK\\jdk-[VERSION_NUMBER]-hotspot`

## Build

To build locally without using SSDX, do the following:

1. If you haven't authenticated a DX user to production / DevHub, run `sfdx auth:web:login -d -a production` and log in
    - Ask `#crm-platform-team` on Slack if you don't have a user
    - If you change from one repo to another, you can change the default DevHub username in `.sfdx/sfdx-config.json`, but you can also just run the command above
2. Create a scratch org, install dependencies and push metadata:

```bash
sfdx force:org:create -f ./config/project-scratch-def.json --setalias scratch_org --durationdays 1 --setdefaultusername
echo y | sfdx plugins:install sfpowerkit@2.0.1
keys="" && for p in $(sfdx force:package:list --json | jq '.result | .[].Name' -r); do keys+=$p":{key} "; done
sfdx sfpowerkit:package:dependencies:install -u scratch_org -r -a -w 60 -k ${keys}
sfdx force:source:push
sfdx force:org:open
```

## Pre scratch setup

Scratch deploy will fail due to sharing, seemingly due to Salesforce setting public sharing by default when using Developer edition of scratch. If that is the case you need to set Case and Opportunity Internal Access to Private in Sharing Settings to match platform-base sharing settings. Then continue deployment.

## Post scratch setup
As some metadata have poor support for packaging and metadata deployment there are a few manual steps to perform to be able to test the chat solution.


1. 
    - Run this command in the terminal

    ```
    npm run scratchSetup
    ```
2. Give access to Messaging
    - Go to Setup -> Users -> "User, User" and add Messaging for In-App and Web User to Permission Set License Assignments.

3. Add Messaging Session to Scratch Chat Queue
    - Setup -> Queues -> Scratch Chat Queue -> Add Messaging Session in selection.

4. Create a Messaging Channel
    - Go to Setup -> Messaging Settings -> Make sure Messaging is ON. Then press New Channel -> Messaging for In-App and Web. Under Omni-Channel Routing set Routing Type to Omni-Queue and assign Scratch Chat Queue. Make sure to activate the channel.

5. Create an Embedded Service Deployment
    - Go to Setup -> Embedded Service Deployments -> New Deployment -> Messaging for In-App and Web -> Web -> Add the domain name of the experience site. Make sure the domain name is without any prefixes (Example: enterprise-power-8072-dev-ed.scratch.my.site.com). Make sure to publish it after it is created.

6. Add URL to Trusted URLs
    - Go to Setup -> Trusted URLs and add the SCRT-URL from the Embedded Service Deployment's Code Snippet "scrt2URL" to Trusted URLs. Example: https://enterprise-power-8072-dev-ed.scratch.my.salesforce-scrt.com. Allow all CSP Directives.

7. Add URL to CORS
    - Go to Setup -> CORS and add your experience site url.

8. Experience Site
    - Go to the experience site scratch_innboks and into builder. Add the "Embedded Messaging" component to the site and set the Embedded Web Deployment, Enhanced Service URL and Site Endpoint. 

    - In the experience site builder, open settings -> Security and privacy and enable Relaxed CSP (if not already enabled). Then under the CSP Errors section allow the two sites that have been blocked from the live agent endpoints (if they are blocked - check CSP Errors and console log).
    - Navigate to the workspace of scratch-innboks. The easiest way to get there is the hamburger in the top left of the builder. Go to Administration -> Members and add customer profile Scratch Community Profile and save.

9. Add service presence status to permission set
    - Go to setup -> Permission sets -> Scratch Permission set and add access to the service presence statuses needed for chat.

10. Add Messaging channel to Presence Status
    - Go to setup -> Presence Statuses -> Tilgjengelig for chat -> Edit and add Messaging to selected channel.


11. To start a chat find the Harry Potter Account and the use the Log In to Experience as User action.
12. To receive a chat go to an app with omni-console enabled, such as the scratch app, and change your omni-channel presence to Tilgjengelig for chat.

Other useful commands included in this package:

```
#Activate api mock for all profiles
npm run activateMock
#Deactive mock for all profiles
npm run activateMock
```

# Henvendelser

Enten:
Spørsmål knyttet til koden eller prosjektet kan stilles som issues her på GitHub

Eller:
Spørsmål knyttet til koden eller prosjektet kan stilles til teamalias@nav.no

## For NAV-ansatte

Interne henvendelser kan sendes via Slack i kanalen #crm-nks.
