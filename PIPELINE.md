# GitLab CI/CD Pipeline Documentation

## 1. High-Level Overview

This pipeline automates the provisioning of infrastructure and the deployment of the Corax cluster on the cloud.ru cloud provider. It is designed to be a complete end-to-end solution, starting from infrastructure creation and ending with a fully configured and running application, including monitoring.

### 1.1. Key Technologies

*   **Orchestration**: GitLab CI/CD
*   **Infrastructure as Code (IaC)**: OpenTofu (a fork of Terraform)
*   **Configuration Management**: Ansible
*   **Scripting**: Bash, Python
*   **Cloud Provider**: cloud.ru

### 1.2. Core Workflow

The pipeline follows a structured, multi-stage process to ensure a reliable deployment:

1.  **Configuration Generation**: Dynamically creates configuration files for Ansible (inventories, group variables) and OpenTofu based on GitLab CI/CD variables.
2.  **Networking Setup**: Configures networking routes using the cloud.ru Magic Router to ensure communication between different virtual private clouds (VPCs).
3.  **Infrastructure Provisioning**: Uses OpenTofu to create the required virtual machines (VMs) for the Corax cluster.
4.  **Node Preparation**: Prepares the newly created VMs by setting up SSH access, configuring `/etc/hosts`, and setting up `sudo` permissions.
5.  **Deployment Node Initialization**: Installs necessary software (Ansible, Python, etc.) on a dedicated deployment node, which then orchestrates the application deployment.
6.  **Application Deployment**: Transfers the Corax application archive and configurations to the deployment node and then runs a series of Ansible playbooks to install, configure, and start the Corax components (Kafka, Zookeeper, etc.).
7.  **Monitoring and Auditing (JAM)**: The final stage sets up journaling, auditing, and monitoring for the newly deployed cluster.

## 2. Detailed Stage Breakdown

This section provides a detailed explanation of each stage in the pipeline.

### 2.1. `config_generation`

*   **Goal**: To generate all necessary configuration files for the subsequent stages, including Ansible inventories, group variables, and `ansible.cfg`.
*   **Scripts**:
    *   `ci/scripts/validate_security_mode.sh`: Validates the `CLUSTER_SECURITY_MODE` variable.
    *   `ci/scripts/generate_inventory.py`: Creates the main Ansible inventory (`inventory.ini`) for the Corax cluster nodes.
    *   `ci/scripts/generate_inventory_deploy.py`: Creates a separate inventory for the deployment node (`inventory_deploy.ini`).
    *   `ci/scripts/generate_group_vars.sh`: Generates Ansible group variables (`group_vars/all.yaml`).
    *   `ci/scripts/generate_ansible_cfg.sh`: Creates the `ansible.cfg` file.
    *   `ci/scripts/prepare_security_config.sh`: Prepares security-related configurations.
*   **Dependencies**: None. This is the first stage.
*   **Key Variables**:
    *   `CORAX_NODES`: A JSON array describing the nodes in the cluster.
    *   `SSH_PRIVATE_KEY`: The SSH private key for accessing the nodes.
    *   `CLUSTER_SECURITY_MODE`: The security mode for the cluster (e.g., `ssl`).
*   **Artifacts**: The generated configuration files are saved as artifacts in the `${RUNNER_WORKDIR}` directory.

### 2.2. `api:magic-router`

*   **Goal**: To configure the cloud.ru Magic Router by adding static routes, enabling communication between the GitLab runner's VPC and the Corax cluster's VPC.
*   **Scripts**:
    *   `ci/scripts/add_route_cloud_paas.sh`: A script that interacts with the cloud.ru API to add the necessary routes.
*   **Dependencies**: `generate_configs`.
*   **Key Variables**: This stage likely relies on environment variables for API authentication and network details, which are expected to be configured in the GitLab CI/CD settings.

### 2.3. `connectivity`

*   **Goal**: To ensure the GitLab runner can connect to the cluster's subnet by adding a local route on the runner itself.
*   **Scripts**:
    *   `ci/scripts/add_route_runner.sh`: A script that adds a route to the runner's routing table.
*   **Dependencies**: `generate_configs`, `api:magic-router`.
*   **Key Variables**:
    *   `CLUSTER_SUBNET`: The CIDR of the cluster's subnet.
    *   `RUNNER_GW`: The gateway for the GitLab runner.

### 2.4. `terraform`

*   **Goal**: To provision the virtual machines for the Corax cluster using OpenTofu.
*   **Scripts**:
    *   `terraform-ci/scripts/generate_tfvars.py`: Generates the `terraform.tfvars` file from GitLab CI/CD variables.
    *   `1_get_tofu.sh`, `3_get_cloudru_provider.sh`: Scripts to download and set up OpenTofu and the cloud.ru provider.
*   **Dependencies**: `generate_configs`.
*   **Key Actions**:
    1.  `tofu init`: Initializes the OpenTofu workspace.
    2.  `tofu validate`: Validates the OpenTofu configuration.
    3.  `tofu plan`: Creates an execution plan.
    4.  `tofu apply -auto-approve`: Applies the plan to create the infrastructure.
*   **Artifacts**: `terraform.tfvars` and a debug log are saved as artifacts.

### 2.5. `cluster_setup`

*   **Goal**: To perform initial configuration on all newly created nodes in the cluster.
*   **Key Actions**:
    *   **SSH Key Distribution**: Adds the public SSH key to the `authorized_keys` file on each node.
    *   **/etc/hosts Update**: Populates the `/etc/hosts` file on each node with the hostnames and IP addresses of all cluster nodes.
    *   **Sudoers Configuration**: Configures passwordless `sudo` for the `root` user.
    *   **SSH Access Verification**: Checks that SSH access is working correctly.
*   **Dependencies**: `generate_configs`, `terraform:apply`.
*   **Key Variables**:
    *   `DEPLOY_NODE_HOST`: The IP address of the deployment node.
    *   `CORAX_NODES`: The JSON array describing the cluster nodes.

### 2.6. `deploy_node_init`

*   **Goal**: To prepare the dedicated deployment node for orchestrating the application deployment.
*   **Key Actions**:
    *   Installs essential packages like `ansible`, `unzip`, `python3`, etc., using `apt-get`.
*   **Dependencies**: `cluster_setup`, `generate_configs`.
*   **Key Variables**:
    *   `DEPLOY_NODE_HOST`: The IP address of the deployment node.
    *   `DEPLOY_NODE_USER`: The user for the deployment node.

### 2.7. `archive_deployment`

*   **Goal**: To transfer the Corax application archive and all necessary configuration files to the deployment node.
*   **Key Actions**:
    *   Creates a backup of any existing deployment directory.
    *   Copies the application archive (`CORAX_ARCHIVE`) from the runner to the deployment node.
    *   Unzips the archive on the deployment node.
    *   Copies the dynamically generated configuration files (inventories, group variables, etc.) from the runner to the deployment node, overwriting any existing files from the archive.
*   **Dependencies**: `deploy_node_init`, `generate_configs`.
*   **Key Variables**:
    *   `CORAX_ARCHIVE`: The name of the application archive file.
    *   `DISTRIBS_DIR`: The directory on the runner where the archive is located.
    *   `CORAX_DIR`: The target directory on the deployment node.

### 2.8. `corax_deployment`

*   **Goal**: To deploy and configure the Corax application using Ansible.
*   **Key Actions**:
    *   Executes a series of Ansible playbooks from the deployment node to install, configure, and start the Corax components, including:
        *   `lvm.yaml`
        *   `playbook.yaml`
        *   `prepare_corax.yaml`
        *   `kafka-zookeeper-SE.yml`
        *   `crxsr.yml`
        *   `crxui.yml`
        *   `post_install_corax.yaml`
*   **Dependencies**: `archive_deployment`, `generate_configs`.
*   **Note**: This stage is set to `when: manual`, meaning it requires manual intervention to run. This is a safety measure for the main deployment step.

### 2.9. `jam` (Journaling, Auditing, Monitoring)

*   **Goal**: To set up monitoring, auditing, and journaling for the Corax cluster.
*   **Key Actions**:
    *   Generates a `secrets.yaml` file with sensitive information.
    *   Copies various configuration files to the deployment node.
    *   Runs Ansible playbooks for:
        *   `audit.yaml`
        *   `journal.yaml`
        *   `corax_redos.yaml` (for monitoring with `vmagent`)
*   **Dependencies**: `corax_deployment`, `generate_configs`.
*   **Note**: This stage is also set to `when: manual`.

## 3. Potential Improvements and Bottlenecks

This section provides suggestions for refactoring and improving the pipeline.

### 3.1. Sequential Operations

*   **Bottleneck**: The `cluster_setup` stage configures each node sequentially in a `for` loop. As the number of nodes in the cluster grows, this will become a significant bottleneck, increasing the pipeline execution time.
*   **Suggestion**: Refactor this stage to use Ansible for the initial node setup. Ansible can perform these tasks in parallel, which would dramatically speed up the process. This would also centralize more of the configuration logic in Ansible, rather than spreading it across shell scripts and Ansible playbooks.

### 3.2. Redundant SSH Connections

*   **Bottleneck**: Multiple stages make repeated SSH connections to the same hosts. For example, `cluster_setup`, `deploy_node_init`, and `archive_deployment` all connect to the deployment node.
*   **Suggestion**: Consolidate some of these tasks. For instance, the package installation on the deployment node (`deploy_node_init`) could be merged into an Ansible playbook that runs as part of a larger, initial setup phase.

### 3.3. Use of a Deployment Node

*   **Redundancy**: The pipeline relies on a dedicated deployment node to run Ansible playbooks. While this is a common pattern, it adds an extra layer of complexity. The GitLab runner itself is capable of running Ansible.
*   **Suggestion**: Consider running the Ansible playbooks directly from the GitLab runner. This would eliminate the need for the `deploy_node_init` and `archive_deployment` stages, simplifying the pipeline and reducing the number of SSH connections and file transfers. This would require the runner to have Ansible and the necessary Python libraries installed.

### 3.4. Pre-baked VM Images

*   **Bottleneck**: The `deploy_node_init` stage installs software on the deployment node at runtime. This can be slow and is prone to network-related failures.
*   **Suggestion**: Use a pre-baked VM image (also known as a "golden image") that already has all the necessary software (Ansible, Python, etc.) installed. This would make the provisioning process faster and more reliable. This can be achieved using tools like Packer.

### 3.5. Secrets Management

*   **Security Risk**: The `jam` stage creates a `secrets.yaml` file with sensitive information and passes it as an artifact. While GitLab CI/CD secures artifacts, a better approach is to use a dedicated secrets management solution.
*   **Suggestion**: Integrate the pipeline with a secrets manager like HashiCorp Vault or GitLab's built-in secrets management. This would allow the pipeline to fetch secrets at runtime without exposing them in artifacts.
