# Getting Started with Coded UiPath Agents

In this workshop, you will build your first coded agent on UiPath. We will do the following five tasks:

1. Create an AI agent in UiPath Studio Web
2. Clone the Agent to code and run it locally in your IDE
3. Update the Agent to use an API tool
4. Evaluate its performance
5. Improve it using evaluation feedback

By the end of the workshop, you will have built a working AI-powered automation agent and know how to test it using evaluation sets.

* * *
This example builds an agent that validates addresses, but you can build your agent to do almost anything. 

If you are looking for ideas, check out our [common hackathon ideas for agents.](Agent-Ideas.md)

## Prerequisites
This lab assumes you have the following:
- **UiPath account on staging.uipath.com** — the ``Clone as Coded Agent`` feature used in this workshop is available on the staging environment. Sign up or log in at [staging.uipath.com](https://staging.uipath.com) before starting.
- **USPS Developer account** *(required for Step 10)* — Step 10 adds a real address-validation API to your agent using USPS. You will need a free USPS developer account with a registered app to get a Client ID and Client Secret. [Register at cop.usps.com](https://cop.usps.com/) — allow 15–20 minutes if you're setting this up for the first time. You can complete Steps 1–9 while waiting for access.
- **VS Code** with Python 3.11+ is assumed for the lab instructions.
- **Bash terminal** — the commands in this lab use Bash syntax. In VS Code, open a new terminal and select **Git Bash** (or equivalent) as the terminal type. PowerShell and CMD syntax differ and may cause unexpected errors.
- **uv** — a fast Python package manager used throughout this lab. It is preferred over `pip` because it is significantly faster, handles virtual environment activation automatically, and is the recommended path in the UiPath SDK docs. Install it with:
  ```bash
  pip install uv
  ```
  or see the [uv installation docs](https://docs.astral.sh/uv/getting-started/installation/) for other options. **If you cannot install `uv`** (e.g., due to corporate restrictions), activate your virtual environment manually and replace `uv run uipath ...` with `uipath ...` throughout the lab.
- **Admin rights** — installing packages (`uv`, the UiPath SDK, and dependencies) requires admin/elevated permissions. If you are on a work laptop with restrictions, confirm you can install packages before starting, or work with your IT team in advance.
- No existing knowledge of UiPath is required for this lab, but it will make it go faster.

# Workshop: Building a Coded Agent in UiPath

## Step 1 — Open UiPath Studio Web
Log into [staging.uipath.com](https://staging.uipath.com) and navigate to **Studio** from the side menu. You should see your **Cloud Workspace**.

Click ``Create New``

![step-01.png](images/step-01.png)



## Step 2 — Choose What to Build
When creating a new solution you will see multiple options:  

- Agentic Process
- Agent
- RPA Workflow
- API Workflow
- App
- Case Management

For this workshop select ``Agent``

![step-02.png](images/step-02.png)


## Step 3 — Generate an Agent with Autopilot
We can use UiPath Autopilot to generate an agent from a simple description.  

To demonstrate this, do the following:
1. Select ``Autonomous`` as the agent type
2. Enter a prompt for ``what your agent should do``. For example:

```
You are an address parser, you will be provided with a single string of an address and your job is to break it down into the following parts:
- streetNumber: the house/building number.​
- preDirectional: directional prefix before the street name (N, S, E, W,
NE, NW, SE, SW).​
- streetName: the primary street name only, without number, direction, or
suffix.​
- streetType: the street suffix (St, Ave, Blvd, Dr, Ln, Rd, Ct, Pl, Way, Cir,
etc.) in abbreviated form.​
- postDirectional: directional suffix after the street name/type.​
- unitType: secondary designator (Apt, Suite, Unit, Bldg, Floor, Rm, #).​
- unitNumber: the unit number or letter.​
- city: the city or municipality.​
- state: 2-letter US state/territory abbreviation.​
- zipCode: 5-digit ZIP code.​
- zipPlus4: 4-digit ZIP+4 extension (no dash). Empty if not provided.​
- country: defaults to \"US\" unless explicitly stated otherwise.
```

3. Click the ``Generate Agent`` button

![step-03a.png](images/step-03a.png)

4. Review and accept Autopilot's recommendations as it configures your new Agent Solution

![step-03b.png](images/step-03b.png)


## Step 4 — Review the Agent Canvas

Once created, the **Agent Canvas** will appear.  

Selecting the agent, Studio will open up the properties window, where you can configure properties such as:  

- Model
- System Prompt
- User Prompt
- Tools
- Input/Output arguments
- Context
- Guardrails

The properties are also accessible using the wrench icon in the upper-right corner of the Studio design canvas.

![step-04.png](images/step-04.png)


## Step 5 — Clone the Agent as a Coded Agent
To customize your agent with code, do the following:
1. Click on the ``Clone as Coded Agent`` button at the top of the design canvas.

2. Review the new ``Coded Copy of Agent`` part of the solution - this is code that was generated, which we will open in the next step.

![step-05.png](images/step-05.png)

## Step 6 — Open the Project in VS Code
Let's open the generated project in **VS Code** and examine its contents.

1. Create a new empty folder for your project and open it in VS Code (**File → Open Folder**). This folder will be your project workspace — all commands in the lab run from its root.

2. Install the [UiPath Python SDK](https://github.com/UiPath/uipath-python) into your project using [the installation instructions on the UiPath Python SDK Getting Started with the CLI page](https://uipath.github.io/uipath-python/core/getting_started/#getting-started-with-the-cli).

3. Validate the SDK has been installed by checking the version number:

   ```bash
   uipath --version
   ```

   The response will be something like: ``uipath version 2.0.29``

4. Authenticate to the UiPath staging environment. This will open a web browser to complete authentication:

   ```bash
   uipath auth --staging
   ```

   - If you are a member of multiple UiPath organizations, you may be prompted to select which one to use.
   - If you have multiple tenants in your organization, you may be prompted to select a tenant.

5. Add your UiPath project information to the `.env` file that was created once you successfully authenticated and selected your tenant:

   ```yml
   UIPATH_PROJECT_ID=abcdef12-3456-7890-abcd-ef1234567890
   ```

   You can find your Project ID number in Studio Web...
      1. Select the coded agent node in your Solution
      2. Look at the Studio Web URL and copy the ID number that is after `url/designer/` but before the `?solutionId=`

      ![step-06b.png](images/step-06b.png)

   Note: If the project didn't create a ``.env`` file in the root of your project when you authenticated, you can create one in your IDE and authenticate again using the ``uipath auth`` command above.


6. **Pull the coded agent project** that you created in UiPath Studio Web using the following command and selecting ``y`` to overwrite the local files:

   ```bash
   uipath pull
   ```

   ![step-06c.png](images/step-06c.png)

7. Initialize the project to generate the entry points needed to run the agent:

   ```bash
   uipath init
   ```


## Step 7 - Explore the new Project
Now that the project is on your local machine, let's take a moment and explore what is in the project.

Your project structure includes the following files. While some of these files may be empty, we will populate them in the next step.  

* ``AGENTS.md`` describes the CLI commands that are available from the Python SDK that your coding agent can make use of. The file both defines the role of your coding agent and the UiPath skills that are available to it.
   * This file and those in the ``.agent`` folder comes from the Python SDK.
   * The SDK also creates a ``CLAUDE.md`` file that points Claude Code to this file
* ``main.py`` contains the agent properties that we setup in UiPath Studio Web
* ``input.json`` provides the input values that the agent will use when it runs. This file is likely empty for you to start.
* ``evaluations/`` folder containing your evaluation set files (e.g., ``evaluations/eval-sets/evaluation-set-default.json``) — you will use these in Step 11

![step-07.png](images/step-07.png)

## Step 8 — Run the Agent with input values
Run the agent locally using the CLI.

1. Populate the `input.json` file to store the address that you want to pass as an input parameter to the agent. If the file doesn't exist, create it in the root of the project:

   ```json
   {
      "address": "1600 Pennsylvania Ave NW, Washington DC 20500"
   }
   ```

2. Run the agent locally using the following command, which will use address in your `input.json` file and run the agent:

   ```bash
   uv run uipath run agent --file input.json
   ```

![step-08.png](images/step-08.png)


## Step 9 — Review the Agent Output
The terminal will display the parsed address components.  

You should see the following in the output:  
- street number
- street name
- city
- state
- zip code

![step-09.png](images/step-09.png)


## Step 10 — Add an External API Tool
Having a well-crafted agent prompt is awesome, but there is so much more that they can do when equiped with tools such as external APIs.

To demonstrate use of external APIs, let's add the **USPS validation API** to our agent. 

To do this, we will need to do the following:  

1. Register for a USPS account at [https://cop.usps.com/](https://cop.usps.com/) - and create a 'business account' on the website so that you have access to their developer APIs

   ![step-10a.png](images/step-10a.png)

   ![step-10b.png](images/step-10b.png)

2. Once you have a developer account created, create an application by selecting ``my apps`` from the top nav, select the ``developer apps`` tab, and create an app entry to call the APIs.

   ![step-10c.png](images/step-10c.png)

3. Add your USPS Client ID and Client Secret to your ``.env`` file. This will enable your agent to call the service.

   ```yaml
   USPS_CLIENT_ID=your_client_id
   USPS_CLIENT_SECRET=your_client_secret
   ```


4. Add the code to call the service (e.g., tools.py)
5. Update the agent to call that tool

To accelerate this work, you can use an AI coding agent (e.g., Claude Code) to update the agent to use this API. A prompt such as the below should work:  

```
Let's update this coded agent to use the addressesv3 API from USPS to validate the address.
- I've updated the .env file to include my USPS_CLIENT_ID and USPS_CLIENT_SECRET
- I need you to add the proper tool to call the APIs and to update the prompt so that the agent calls that tool
```

Your ***AI coding agent*** should now update your ***coded agent*** to use the USPS service, you can test it out using the same run command you used in Step 8.  

```bash
uv run uipath run agent --file input.json
```

Upon execution, the agent should:  

1. Parse the address
2. Validate the address via API
3. Return normalized output


As the agent is running, you should see in the terminal the calls to the USPS service...

![step-10d.png](images/step-10d.png)

...and a more fully formed address...

![step-10e.png](images/step-10e.png)


## Step 11 — Run Evaluation Tests
We will now use the evaluation suite to test and score how well our agent does its job.

1. Copy the ``EVALS.md`` file (in this repo) into the ``.agents`` folder in your coded agent project. This file is a reference guide for your AI coding agent — it contains the evaluation framework patterns and examples it needs to write good test cases.

   ![step-11a.png](images/step-11a.png)

2. Ask your coding agent to use ``EVALS.md`` to create your evaluation test cases. You can use the following prompt:

   ~~~
   Use @.agents/EVALS.md to create 3 evaluation test cases to test various address examples - testing for addresses that are invalid, have a misspelled city, or that have messy formatting. 
   ~~~

3. Run the evaluation:

   ```bash
   uv run uipath eval agent evaluations/eval-sets/evaluation-set-default.json --workers 10 --output-file eval-results.json
   ```

Evaluation tests may include:  

- valid address (e.g., building number too high/low)
- invalid address (e.g., non-existant city)
- misspelled city name
- messy formatting 

![step-11b.png](images/step-11b.png)


## Step 12 — Review Evaluation Results
Open **Evaluation Sets** in UiPath Studio.  
You will see evaluation scores such as:  

- semantic similarity
- agent trajectory

![step-12.png](images/step-12.png)


## Step 13 — Inspect Evaluation Traces
Click an evaluation to see the detailed trace.  
This shows:  

- agent reasoning
- API calls
- intermediate outputs

![step-13.png](images/step-13.png)


## Step 14 — Iterate and Improve the Agent *(Optional)*
Edit the logic inside ``main.py`` to improve your address validator.

Example improvements:  

- better parsing
- stronger validation
- improved formatting


## Step 15 — Rerun the Agent *(Optional)*
After making changes, rerun your agent, using either the ``input.json`` or eval sets you already created.

```bash
uv run uipath run agent --file input.json
```
```bash
uv run uipath eval agent evaluations/eval-sets/evaluation-set-default.json --workers 10 --output-file eval-results.json
```

Afer running your eval sets, you can return again to the Studio Web and hopefully see the scores inprove.

![step-15.png](images/step-15.png)


## Step 16 — Push Coded Agent Updates to UiPath
Push the updated project back to Studio Web to create a version/snapshot of your coded agent.

```bash
uipath push
```

Then commit and push your code for version control system, if applicable.

*Note: If you receive errors while pushing your code back to UiPath, check to see if you are still authenticated. If needed, quickly reauthenticate using ``uipath auth --staging --force``*

* * *
## Congratulations!

You've successfully created a coded agent that runs on UiPath!
- You quckly created an agent using simply a prompt in UiPath Studio Web
- You brought your low-code agent into an IDE and extended it to call an external, credential-protected API -- all from a prompt to your coding agent.
- You then set up evaluation tests to exercise your agent - evaluating both the happy path (well formed inputs) and evaluations that tested bad and malformed inputs
- Finally, you pushed your coded agent back into UiPath 

Next, we invite you to try out more of the platform.