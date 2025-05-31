# Blockcast Node Auto-Installer Script

This script automates the setup and installation of a Blockcast node on Debian/Ubuntu-based Linux systems. It aims to simplify the process by handling dependency installation, Docker setup, Blockcast software deployment, and guiding the user through the necessary registration steps.

## Features

* **Automated Dependency Installation:** Installs required system packages.
* **Docker & Docker Compose Setup:** Installs Docker CE and Docker Compose plugin (skips if Docker is already installed and functional).
* **Blockcast Software Deployment:** Clones or updates the official Blockcast node repository.
* **Service Management:** Automatically starts the Blockcast services using Docker Compose.
* **Guided Account Registration:** Includes a step with a referral link to guide users through Blockcast account creation/login before node registration.
* **Location Data Fetching:** Automatically retrieves public IP and location data (City, Region, Country, Coordinates) to assist with node registration.
* **Automated Node Initialization:** Runs `blockcastd init` to obtain the unique Node Registration URL.
* **User-Friendly Output:** Provides color-coded, step-by-step output with clear instructions and status messages.
* **Interactive Pauses:** Pauses for mandatory manual steps that require web browser interaction.

## Source Documentation

This script is based on and automates many of the steps outlined in the official Blockcast Node installation documentation:
* **Official Guide:** [Blockcast Installation Documentation](https://documentation.codeblocklabs.com/blockchain-nodes/blockcast/installation)

## Prerequisites

* **Operating System:** A Debian/Ubuntu-based Linux system (e.g., Ubuntu 20.04 LTS, Ubuntu 22.04 LTS).
* **Permissions:** `sudo` privileges are required to install packages and manage services.
* **Internet Connection:** Required for downloading packages, cloning the repository, and interacting with the Blockcast platform.
* **Basic Command-Line Knowledge:** Familiarity with using the Linux terminal.
* **Required Tools:** The script will attempt to install `git`, `jq`, `curl`, and `awk` if they are not found. Having them pre-installed can be beneficial.

## How to Use

1.  **Download the Script:**
    ```bash
    wget https://raw.githubusercontent.com/WINGFO-HQ/Blockcast/refs/heads/main/blockcast.sh && chmod +x blockcast.sh && blockcast.sh
    ```

## Installation Process Overview

The script performs the following steps:

1.  **Prerequisite Checks:** Verifies if essential command-line tools are installed and prompts for installation if missing.
2.  **System Update & Dependencies:** Updates package lists, upgrades existing packages, and installs necessary system dependencies.
3.  **Docker Setup:** Checks for an existing Docker installation. If not found or not working, it installs Docker CE, Docker CLI, Containerd, and the Docker Compose plugin. Adds the current user to the `docker` group (logout/login might be needed for changes to take effect for non-sudo docker commands).
4.  **Blockcast Software Setup:**
    * Clones the Blockcast node software from the official GitHub repository (or updates it if already cloned).
    * Starts the Blockcast services (`blockcastd`, `redis`) using `docker compose up -d`.
5.  **Blockcast Account Registration (Manual Web Step):**
    * The script will display a dashboard register link: `https://app.blockcast.network?referral-code=xTCw3m`.
    * It will instruct you to open this link in your browser to create a new Blockcast account or log into an existing one.
    * The script will **pause** and wait for you to press [Enter] before proceeding. This step is crucial as node registration usually requires an active account session.
6.  **Node Initialization & Information Gathering:**
    * Fetches your public IP address and estimated location details (City, Region, Country, Coordinates) using `ipinfo.io`.
    * Runs the `docker compose exec blockcastd blockcastd init` command to initialize your node locally and generate a unique Node Registration URL.
7.  **Node Registration on Dashboard (Manual Web Step):**
    * The script will display the **Node Registration URL** obtained from the previous step.
    * It will instruct you to copy this URL and paste it into your web browser (where you should already be logged into your Blockcast account).
    * You will then need to fill in your node's details on the Blockcast dashboard, using the location information provided by the script as a guide.
    * After completing the form on the website, your node should appear online in the dashboard after a few minutes.

## Referral Link

Please note that this script includes a step (Step 3.5) that presents a referral link for creating a Blockcast account:
`https://app.blockcast.network?referral-code=xTCw3m`
Using this link may provide a referral bonus as per Blockcast's referral program terms.

## Important Notes

* **Sudo Usage:** This script uses `sudo` for package installation and service management. Please review the script if you have any concerns.
* **Port Usage:** Ensure that port **18080** (or the port configured in Blockcast's `docker-compose.yml` if you modify it) is not already in use by another application on your server.
* **Manual Web Steps:** The script automates command-line tasks. However, **Blockcast account creation/login** and the **final node registration on the web dashboard** are manual steps that require your interaction with a web browser.
* **OS Compatibility:** The script is designed and tested for Debian/Ubuntu-based systems due to its use of `apt-get`.
* **URL Extraction:** The script attempts to automatically extract the "Register URL" from the output of the `blockcastd init` command. This relies on a specific output format. If Blockcast changes this output format, the script's URL extraction logic might need an update. A fallback to generic extraction and displaying the full output is included.
* **Idempotency:** The script attempts to be idempotent where possible (e.g., skipping Docker installation if already present, pulling updates if the repo exists).

## Customization

The following variables are defined at the top of the script and can be modified if necessary:

* `BLOCKCAST_REPO`: The URL of the Blockcast node GitHub repository.
* `BLOCKCAST_DIR`: The local directory name where the repository will be cloned.

## Basic Troubleshooting

* **Service Failures:** If Blockcast services fail to start after `docker compose up -d`, navigate to the `blockcast` directory (default) and check the logs:
    ```bash
    cd blockcast
    docker compose logs -f
    ```
* **Permissions:** If you encounter permission issues with Docker commands after the script adds your user to the `docker` group, you might need to log out and log back in, or open a new terminal session.
* **Internet Connection:** Ensure a stable internet connection throughout the process.
* **Dependencies:** If any core dependencies fail to install, the script will warn you. You may need to investigate and install them manually.
