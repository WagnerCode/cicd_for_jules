# GitLab CI/CD Pipeline Documentation

## 1. Architecture and logic

This pipeline automates the provisioning of infrastructure and the deployment of the Corax cluster on the cloud.ru cloud provider. It is designed as an end-to-end solution, handling everything from infrastructure creation to a fully configured and running application, including monitoring.

### 1.1. Key Technologies

*   **Orchestration**: GitLab CI/CD
*   **Infrastructure as Code (IaC)**: OpenTofu (a fork of Terraform)
*   **Configuration Management**: Ansible
*   **Scripting**: Bash, Python
*   **Cloud Provider**: cloud.ru

### 1.2. Core Workflow

The pipeline follows a structured, multi-stage process to ensure a reliable and repeatable deployment:

1.  **Configuration Generation**: Dynamically creates configuration files for Ansible (inventories, group variables) and OpenTofu based on GitLab CI/CD variables. This ensures that each pipeline run is configured from a single source of truth.
2.  **Networking Setup**: Configures networking routes using the cloud.ru Magic Router and on the GitLab Runner itself. This is a critical step to ensure communication between the runner's environment and the newly created virtual private cloud (VPC) for the Corax cluster.
3.  **Infrastructure Provisioning**: Uses OpenTofu to provision the required virtual machines (VMs) for the Corax cluster based on the generated configuration.
4.  **Node Preparation**: Performs initial setup on the newly created VMs. This includes distributing SSH keys for secure access, updating the `/etc/hosts` file for name resolution within the cluster, and configuring `sudo` permissions.
5.  **Deployment Node Initialization**: A dedicated "deployment node" is prepared with all the necessary software (like Ansible and Python) to orchestrate the application deployment across the cluster.
6.  **Application Deployment**: The Corax application archive and all generated configurations are transferred to the deployment node. From there, a series of Ansible playbooks are executed to install, configure, and start all the components of the Corax application (e.g., Kafka, Zookeeper).
7.  **Monitoring and Auditing (JAM)**: The final stage sets up Journaling, Auditing, and Monitoring for the newly deployed cluster, ensuring observability from the start.

### 1.3. Modularity

The pipeline is highly modular, using GitLab's `include` keyword to separate different concerns into individual YAML files. The main `.gitlab-ci.yml` file acts as a manifest that includes other files from the `ci/` and `terraform-ci/` directories. This modular structure makes the pipeline easier to understand, maintain, and extend. It also allows for the reuse of templates and functions across different jobs.

## 2. Variables and Scope

This section details the variables used to configure the CI/CD pipeline. Understanding these variables is crucial for customizing and running the deployment.

### 2.1. Variable Sources

Variables are defined in three main locations:

1.  **GitLab CI/CD Settings**: These are the most critical variables and are set at the project or group level in the GitLab UI (`Settings → CI/CD → Variables`). These are used for sensitive information like secrets and for configuration that changes between environments. **These variables take the highest precedence.**
2.  **`.gitlab-ci.yml`**: The main pipeline file, which includes `ci/variables.yml`. This file defines global variables with default values for the entire pipeline. These defaults are suitable for development or testing but can be overridden by variables set in the GitLab UI.
3.  **Job-level `variables` block**: Some jobs may define their own variables for specific tasks. These variables have a local scope and are only available within that job.

### 2.2. Variable Precedence

GitLab CI/CD has a well-defined [variable precedence order](https://docs.gitlab.com/ee/ci/variables/index.html#cicd-variable-precedence). In this pipeline, the order is generally:

1.  Variables set in the GitLab UI (`Settings → CI/CD → Variables`).
2.  Variables defined in the `.gitlab-ci.yml` or included files (e.g., `ci/variables.yml`).

This means **any variable defined in the GitLab UI will override the default values set in the YAML files.**

### 2.3. Variable Reference Table

| Variable                  | Source                     | Default Value                                                                                                                                                                                   | Description                                                                                                                                                                                              |
| ------------------------- | -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`DEPLOY_NODE_HOST`**    | GitLab CI/CD Settings      | `10.79.11.23` (Example)                                                                                                                                                                         | **(Required)** The IP address of the dedicated deployment node. This node orchestrates the Ansible deployment.                                                                                         |
| **`SSH_PRIVATE_KEY`**     | GitLab CI/CD Settings (File) | *None*                                                                                                                                                                                          | **(Required)** The private SSH key used to connect to all nodes. For security, this should be a `File` type variable in GitLab.                                                                         |
| **`CORAX_NODES`**         | GitLab CI/CD Settings      | `[{"name":"corax-node1","host":"10.79.11.23",...}]` (Example)                                                                                                                                    | **(Required)** A JSON array describing the nodes in the Corax cluster, including their names, IP addresses, users, and roles. This is the primary input for generating the Ansible inventory.              |
| **`DEPLOY_NODE_USER`**    | `ci/variables.yml`         | `user1`                                                                                                                                                                                         | The username for connecting to the deployment node.                                                                                                                                                      |
| **`ANSIBLE_USER`**        | `ci/variables.yml`         | `user1`                                                                                                                                                                                         | The default username for Ansible to use when connecting to the cluster nodes.                                                                                                                            |
| **`CLUSTER_SUBNET`**      | `ci/variables.yml`         | `10.79.11.16/28`                                                                                                                                                                                | The CIDR of the subnet where the Corax cluster will be deployed. Used for configuring network routes.                                                                                                    |
| **`RUNNER_GW`**           | `ci/variables.yml`         | `172.18.0.1`                                                                                                                                                                                    | The gateway of the GitLab Runner's network. Used to add a route on the runner for connectivity to the cluster subnet.                                                                                  |
| **`CLUSTER_SECURITY_MODE`** | `ci/variables.yml`         | `ssl`                                                                                                                                                                                           | The security mode for the cluster. Can be `plaintext` (no encryption) or `ssl` (full encryption with certificates). This variable controls which security configurations are applied.                       |
| **`SSL_KEYSTORE_PASSWORD`** | `ci/variables.yml`         | `changeit`                                                                                                                                                                                      | The password for the SSL keystore. **In production, this should be set as a masked variable in GitLab CI/CD Settings.**                                                                                     |
| **`SSL_TRUSTSTORE_PASSWORD`** | `ci/variables.yml`         | `changeit`                                                                                                                                                                                      | The password for the SSL truststore. **In production, this should be set as a masked variable in GitLab CI/CD Settings.**                                                                                    |
| **`SSL_KEY_PASSWORD`**      | `ci/variables.yml`         | `changeit`                                                                                                                                                                                      | The password for the SSL private key. **In production, this should be set as a masked variable in GitLab CI/CD Settings.**                                                                                    |
| **`DISTRIBS_DIR`**        | `ci/variables.yml`         | `/test-distribs`                                                                                                                                                                                | The directory on the GitLab Runner where the application archive (`CORAX_ARCHIVE`) is located.                                                                                                           |
| **`CORAX_ARCHIVE`**       | `ci/variables.yml`         | `corax_prepare.zip`                                                                                                                                                                             | The filename of the Corax application archive.                                                                                                                                                           |
| **`RUNNER_WORKDIR`**      | `ci/variables.yml`         | `${CI_PROJECT_DIR}/corax_prepare`                                                                                                                                                                | The working directory on the GitLab Runner where generated configurations are stored and passed as artifacts between jobs.                                                                               |
| **`ANSIBLE_HOST_KEY_CHECKING`** | `ci/variables.yml`         | `False`                                                                                                                                                                                         | Disables host key checking for Ansible, which is common in dynamic environments where host keys change.                                                                                                  |
| *Other Ansible Vars*      | `ci/variables.yml`         | *Various*                                                                                                                                                                                       | `ci/variables.yml` contains other variables for configuring Kafka, Zookeeper, and Corax UI/SR ports and paths. These have sensible defaults but can be overridden as needed.                             |
| *JAM Stage Vars*          | GitLab CI/CD Settings      | *None*                                                                                                                                                                                          | The `jam` stage requires several variables for connecting to the monitoring system (e.g., `project_id`, `log_group_id`, `sa_journal_api_key`). These must be set in the GitLab CI/CD settings.      |

## 3. Detailed analysis of stages (Step-by-Step)

This section provides a detailed breakdown of each job in the pipeline, following the order of execution defined in `ci/stages.yml`.

### Stage: `config_generation`

This is the first and one of the most important stages in the pipeline. It generates all the necessary configuration files for the subsequent stages.

#### Job: `generate_configs`

*   **Input**:
    *   Relies on GitLab CI/CD variables, primarily `CORAX_NODES`, `DEPLOY_NODE_HOST`, and `SSH_PRIVATE_KEY`.
    *   Reads the `CORAX_ARCHIVE` from the `DISTRIBS_DIR` on the GitLab Runner to perform validation checks.
*   **Process**:
    1.  **Validation**: Performs extensive checks on the runner environment, ensuring that required tools (like `python3`, `ssh`) are installed and that all mandatory variables are set. It also validates the integrity of the `CORAX_ARCHIVE`.
    2.  **Directory Setup**: Creates a clean working directory (`RUNNER_WORKDIR`) to store the generated files.
    3.  **Script Execution**: Executes a series of scripts from the `ci/scripts/` directory:
        *   `validate_security_mode.sh`: Ensures `CLUSTER_SECURITY_MODE` is set to a valid value.
        *   `generate_inventory.py`: Creates the main Ansible inventory (`inventory.ini`) for the Corax cluster nodes from the `CORAX_NODES` variable.
        *   `generate_inventory_deploy.py`: Creates a separate, smaller inventory (`inventory_deploy.ini`) containing only the deployment node.
        *   `generate_group_vars.sh`: Generates Ansible group variables (`group_vars/all.yaml`), populating it with values from the CI/CD variables.
        *   `generate_ansible_cfg.sh`: Creates the `ansible.cfg` file.
        *   `prepare_security_config.sh`: Prepares security-related configurations based on the `CLUSTER_SECURITY_MODE`. If set to `ssl`, it generates SSL certificates.
*   **Output**:
    *   **Artifacts**: Creates a `corax-configs` artifact containing all the generated files. This artifact is saved in the `${RUNNER_WORKDIR}` directory and is passed to subsequent jobs. The artifact includes:
        *   `inventory.ini`
        *   `inventory_deploy.ini`
        *   `group_vars/all.yaml`
        *   `ansible.cfg`
        *   `ssh_private_key`
        *   A `security_config/` directory with security-related files.
*   **Conditions**: This job runs on every pipeline execution.

### Stage: `api:magic-router`

This stage is responsible for configuring the cloud.ru Magic Router to enable network connectivity.

#### Job: `api:magic-router`

*   **Input**:
    *   **Dependencies**: Depends on the `generate_configs` job. While it doesn't use the artifacts directly, it relies on the variables being validated.
    *   Requires cloud provider credentials, which are expected to be configured as environment variables in the GitLab Runner's environment.
*   **Process**:
    1.  Executes the `ci/scripts/add_route_cloud_paas.sh` script.
    2.  This script interacts with the cloud.ru API to add static routes to the Magic Router, allowing traffic to flow between the GitLab Runner's VPC and the newly created cluster's VPC.
*   **Output**:
    *   No artifacts are created. The output is the successful configuration of the cloud networking.
*   **Conditions**: Runs on every pipeline execution.

### Stage: `connectivity`

This stage ensures that the GitLab Runner itself can connect to the cluster's subnet.

#### Job: `connectivity:routes`

*   **Input**:
    *   **Needs**: Explicitly `needs` the `generate_configs` and `api:magic-router` jobs to ensure it runs after them.
    *   Uses the `CLUSTER_SUBNET` and `RUNNER_GW` variables.
*   **Process**:
    1.  Executes the `ci/scripts/add_route_runner.sh` script.
    2.  This script adds a local static route to the GitLab Runner's routing table, directing traffic for the `CLUSTER_SUBNET` through the `RUNNER_GW`.
*   **Output**:
    *   No artifacts are created. The output is a correctly configured network route on the runner.
*   **Conditions**: Runs on every pipeline execution.

### Stage: `terraform`

This stage provisions the virtual machine infrastructure for the Corax cluster.

#### Job: `terraform:apply`

*   **Input**:
    *   **Dependencies**: Depends on `generate_configs`.
    *   Requires cloud provider credentials (API keys, etc.) to be available as environment variables.
*   **Process**:
    1.  **Generate `terraform.tfvars`**: Executes `terraform-ci/scripts/generate_tfvars.py` to convert the GitLab CI/CD variables into a format that OpenTofu can consume.
    2.  **Setup OpenTofu**: Downloads and sets up the OpenTofu binary and the required `cloudru` provider.
    3.  **Terraform Workflow**: Executes the standard OpenTofu workflow:
        *   `tofu init`: Initializes the workspace.
        *   `tofu validate`: Validates the configuration.
        *   `tofu plan`: Creates an execution plan.
        *   `tofu apply -auto-approve`: Applies the plan to create the VMs and other resources.
*   **Output**:
    *   **Artifacts**: Saves the `terraform.tfvars` file and a debug log (`terraform-debug.log`) for troubleshooting.
    *   The primary output is the provisioned infrastructure on cloud.ru.
*   **Conditions**: Runs on every pipeline execution.

### Stage: `cluster_setup`

This stage performs the initial configuration of all newly created nodes in the cluster.

#### Job: `cluster_setup`

*   **Input**:
    *   **Dependencies**: Depends on `generate_configs` and `terraform:apply`.
    *   Uses the artifact from `generate_configs`.
    *   Uses the `CORAX_NODES` and `DEPLOY_NODE_HOST` variables.
*   **Process**:
    1.  **Wait for SSH**: Uses the `wait_for_ssh` function to ensure all nodes are up and accessible via SSH before proceeding.
    2.  **Iterate Through Nodes**: Loops through each node defined in the `CORAX_NODES` variable and performs the following actions via SSH:
        *   **SSH Key Distribution**: Adds the public SSH key to the `authorized_keys` file on each node.
        *   **/etc/hosts Update**: Populates the `/etc/hosts` file on each node with the hostnames and IP addresses of all cluster nodes.
        *   **Sudoers Configuration**: Configures passwordless `sudo` for the `root` user.
        *   **SSH Access Verification**: Checks that SSH access is working correctly.
    3.  **Setup Deploy Node SSH**: Copies the private SSH key to the deployment node so that it can connect to the other cluster nodes.
*   **Output**:
    *   The output is a cluster of VMs that are ready for software installation, with proper SSH access and name resolution configured.
    *   **Artifacts**: Passes on the `corax-configs` artifact.
*   **Conditions**: Runs on every pipeline execution.

### Stage: `deploy_node_init`

This stage prepares the dedicated deployment node by installing necessary software.

#### Job: `deploy_node_init`

*   **Input**:
    *   **Dependencies**: Depends on `cluster_setup` and `generate_configs`.
    *   Uses the `DEPLOY_NODE_HOST` variable.
*   **Process**:
    1.  Connects to the deployment node via SSH.
    2.  Updates the package manager (`apt-get update`).
    3.  Installs essential packages, including `ansible`, `unzip`, `python3`, `git`, and others.
*   **Output**:
    *   A fully configured deployment node with all the tools required to run the Ansible playbooks.
    *   **Artifacts**: Passes on the `corax-configs` artifact.
*   **Conditions**: Runs on every pipeline execution.

### Stage: `archive_deployment`

This stage transfers the Corax application archive and all the generated configurations to the deployment node.

#### Job: `archive_deployment`

*   **Input**:
    *   **Dependencies**: Depends on `deploy_node_init` and `generate_configs`.
    *   Uses the `corax-configs` artifact from the `generate_configs` job.
    *   Uses the `CORAX_ARCHIVE` located in `DISTRIBS_DIR`.
*   **Process**:
    1.  **Backup**: Creates a backup of any existing deployment directory on the deployment node.
    2.  **Copy Archive**: Copies the `CORAX_ARCHIVE` from the runner to the deployment node's `/tmp` directory.
    3.  **Unzip**: Unzips the archive on the deployment node into the target directory (`CORAX_DIR`).
    4.  **Copy Configs**: Copies the dynamically generated configuration files (`inventory.ini`, `group_vars/all.yaml`, `ansible.cfg`, etc.) from the runner to the deployment node, overwriting any versions that were in the archive. This is a critical step that injects the pipeline-generated configuration into the deployment process.
    5.  **Copy Security Config**: Copies the security configurations, including SSL certificates if `CLUSTER_SECURITY_MODE` is `ssl`.
*   **Output**:
    *   A deployment node with the Corax application code and all necessary configurations ready for execution.
    *   **Artifacts**: Passes on the `corax-configs` artifact.
*   **Conditions**: Runs on every pipeline execution.

### Stage: `corax_deployment`

This is the main application deployment stage, where Ansible orchestrates the installation and configuration of the Corax cluster.

#### Job: `corax_deployment`

*   **Input**:
    *   **Dependencies**: Depends on `archive_deployment` and `generate_configs`.
*   **Process**:
    1.  Connects to the deployment node via SSH.
    2.  Executes a series of Ansible playbooks in a specific order:
        *   `lvm.yaml`: Sets up Logical Volume Management on the Kafka nodes.
        *   `playbook.yaml`: A preparatory playbook.
        *   `prepare_corax.yaml`: Prepares the nodes for Corax installation.
        *   `kafka-zookeeper-SE.yml`: Installs and configures Kafka and Zookeeper.
        *   `crxsr.yml`: Installs and configures the Corax SR component.
        *   `crxui.yml`: Installs and configures the Corax UI component.
        *   `post_install_corax.yaml`: Performs post-installation cleanup and configuration.
*   **Output**:
    *   A fully deployed and running Corax cluster.
*   **Conditions**:
    *   `when: manual`: This job requires manual intervention to run. This is a crucial safety feature to prevent accidental deployments to production environments.

### Stage: `jam` (Journaling, Auditing, Monitoring)

The final stage sets up monitoring, auditing, and journaling for the Corax cluster.

#### Job: `jam`

*   **Input**:
    *   **Dependencies**: Depends on `corax_deployment` and `generate_configs`.
    *   Requires several monitoring-related variables to be set in the GitLab CI/CD settings (e.g., `project_id`, `log_group_id`, `sa_journal_api_key`).
*   **Process**:
    1.  **Generate Secrets**: Creates a `secrets.yaml` file with sensitive information required for monitoring.
    2.  **Copy Files**: Copies various configuration files and the secrets file to the deployment node.
    3.  **Run Playbooks**: Executes Ansible playbooks for:
        *   `audit.yaml`: Configures auditing.
        *   `journal.yaml`: Configures journaling.
        *   `corax_redos.yaml`: Sets up monitoring with `vmagent` and configures it to send metrics to the monitoring backend.
*   **Output**:
    *   A fully monitored Corax cluster.
*   **Conditions**:
    *   `when: manual`: This job also requires manual intervention.

## 4. Modification instructions (How-To Guide)

This section provides practical guidance for making common changes to the pipeline.

### 4.1. How to Add a New Stage

Adding a new stage requires a few coordinated changes due to the modular nature of the pipeline.

1.  **Define the Stage**:
    *   Open `ci/stages.yml`.
    *   Add the name of your new stage in the desired order. The order in `stages.yml` dictates the execution flow of the pipeline.

2.  **Create the Job File**:
    *   Create a new YAML file for your job in the appropriate directory (e.g., `ci/jobs/my_new_job.yml`).
    *   Define your job in this file. It's good practice to extend `.common_job` from `ci/templates.yml` to inherit common settings like retry logic.
    *   Assign your job to the new stage using the `stage:` keyword.
    *   ```yaml
      my_new_job:
        stage: my_new_stage
        extends: .common_job
        script:
          - echo "This is my new job!"
      ```

3.  **Include the Job File**:
    *   Open the main `.gitlab-ci.yml` file.
    *   Add a new entry under the `include:` section to include your new job file.
    *   ```yaml
      include:
        - local: 'ci/jobs/my_new_job.yml'
      ```

4.  **Define Dependencies**:
    *   If your new job depends on artifacts from a previous job, use the `needs:` or `dependencies:` keyword. `needs:` is more explicit and can create a DAG (Directed Acyclic Graph), allowing for more parallel execution.
    *   ```yaml
      my_new_job:
        stage: my_new_stage
        needs:
          - job: generate_configs
            artifacts: true
        script:
          - cat ${RUNNER_WORKDIR}/inventory.ini # We can now access the artifact
      ```

### 4.2. How to Change Variables for Deployment

Changing deployment variables (e.g., the number of nodes, IP addresses, software versions) should be done carefully.

1.  **Identify the Variable**:
    *   Refer to the "Variable Reference Table" in section 2.3 to identify the correct variable to change.

2.  **Choose the Right Location**:
    *   **For Sensitive or Environment-Specific Changes (Recommended)**:
        *   Navigate to your project's `Settings → CI/CD → Variables` in the GitLab UI.
        *   Find the variable you want to change (e.g., `CORAX_NODES`) and click "Edit".
        *   Update its value and save. If the variable doesn't exist, add it.
        *   **This is the safest method**, as it doesn't require code changes and allows for different configurations across different branches or environments (using protected branches or environments features).
    *   **For Changing Default Values**:
        *   If you want to change a default value for all pipeline runs (and it's not a secret), you can edit `ci/variables.yml`.
        *   Find the variable and update its default value.
        *   This requires a merge request and will affect all pipelines that don't override the variable in the UI.

3.  **Important Considerations**:
    *   **`CORAX_NODES`**: When changing this JSON array, ensure it is still valid JSON. An error here will cause the `generate_configs` job to fail.
    *   **`SSH_PRIVATE_KEY`**: To update the SSH key, you must edit the `File` type variable in the GitLab CI/CD settings.
    *   **Dependencies**: Be aware of how variables are connected. For example, if you change the IP addresses in `CORAX_NODES`, you might also need to update `DEPLOY_NODE_HOST` if it's one of those nodes. The `generate_inventory.py` script handles the inventory creation, so you won't need to change that manually.

### 4.3. Checklist Before Merging Changes to the Pipeline

Before merging any changes to the `.gitlab-ci.yml` file or any of the included CI/CD configuration files, perform the following checks:

*   **[ ] Linting**: Have you linted your GitLab CI/CD configuration? You can do this in the GitLab UI under `CI/CD → Editor → Lint`. This catches syntax errors.
*   **[ ] Variable Usage**: If you've added a new variable, have you documented it in the "Variables and Scope" section?
*   **[ ] Dependencies**: Are the `stage`, `needs`, and `dependencies` for any new or modified jobs correctly defined?
*   **[ ] Manual Jobs**: Have you considered if any new, potentially destructive jobs should be set to `when: manual`?
*   **[ ] Testing**: Have you tested your changes in a separate branch or a fork of the repository to ensure they work as expected without disrupting the main branch?
*   **[ ] Scripts**: If you've modified any scripts (`.sh`, `.py`), have you tested them independently to ensure they are robust?
