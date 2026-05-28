# CRM-NKS-CHAT

[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://github.com/navikt/crm-shared-template/blob/master/LICENSE)

Repository containing core components for the nks-chat functionality

## Dependencies

This package is dependant on the following packages

- [crm-platform-base](https://github.com/navikt/crm-platform-base)
- [crm-platform-integration](https://github.com/navikt/crm-platform-integration)
- [crm-nks-base-components](https://github.com/navikt/crm-nks-base-components)
- [crm-journal-utilities](https://github.com/navikt/crm-journal-utilities)
- [crm-shared-user-notification](https://github.com/navikt/crm-shared-user-notification)
- [crm-shared-flowComponents](https://github.com/navikt/crm-shared-flowComponents)
- [crm-henvendelse](https://github.com/navikt/crm-henvendelse)

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

## Post scratch setup

As some metadata have poor support for packaging and metadata deployment there are a few manual steps to perform to be able to test the chat solution.
This is solid overall—clear structure and good sequencing—but it can be tightened up for consistency, grammar, and a bit of flow. Here’s a cleaned-up version with minimal changes to your intent:

---

### Setup Steps

1. **Run the setup command in the terminal**

    ```
    npm run scratchSetup
    ```

2. **Activate the "NKS Messaging" channel**

    - Go to **Setup → Messaging Settings**
    - Under _Channels_, click the channel name
    - Click **Activate** (top right corner)

3. **Create an Embedded Service Deployment**

    - Go to **Setup → Embedded Service Deployments → New Deployment**
    - Select: _Enhanced Chat → Web_
    - Add the domain name of the Experience Site

        - Use the domain **without prefixes**
          _(Example: enterprise-power-8072-dev-ed.scratch.my.site.com)_

    - Publish the deployment after creation
    - Copy the **SCRT URL** from the code snippet (`scrt2URL`) before proceeding

4. **Add the URL to Trusted URLs**

    - Go to **Setup → Trusted URLs**
    - Add the SCRT URL copied in the previous step
      _(Example: [https://enterprise-power-8072-dev-ed.scratch.my.salesforce-scrt.com](https://enterprise-power-8072-dev-ed.scratch.my.salesforce-scrt.com))_
    - Allow all CSP directives

5. **Add the URL to CORS**

    - Go to **Setup → CORS**
    - Add your Experience Site URL

6. **Configure the Experience Site**

    - Open the _scratch_innboks_ site in Experience Builder

    - Select the **Embedded Messaging** component on the page

    - Set:

        - Embedded Web Deployment

    - In **Settings → Security & Privacy**:

        - Under _CSP Errors_, allow any blocked domains related to Live Agent endpoints (check console/CSP logs)
        - Ensure **Relaxed CSP** is enabled

7. **Add Service Presence Status to Permission Set (if not already added)**

    - Go to **Setup → Permission Sets → Scratch Permission Set**
    - Add access to the required service presence statuses for chat

8. **Start a chat**

    - Locate the _Harry Potter_ Account
    - Use **Log In to Experience as User**

9. **Receive a chat**

    - Open an Omni-Channel-enabled app (e.g., _Scratch App_)
    - Set your Omni-Channel presence status to **Tilgjengelig for chat**

---

### Notes

- After publishing the Experience Site, if the Embedded Messaging component is not visible, remove it and add it again.

- Update the **Channel ID** and **Default Queue** in the _NKS Messaging Route to Queue_ Omnichannel flow, as these IDs may change. This ensures messaging sessions are routed correctly.

- Ensure your user is a member of the relevant queues to receive chats.

- Make sure **Change Data Capture** is enabled for _Messaging Session_.

---

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

## For Nav-ansatte

Interne henvendelser kan sendes via Slack i kanalen #crm-nks.
