provider "azurerm" {
  features {}
  skip_provider_registration = true
  client_id                  = "your client id"
  client_secret              = "your client secret"
  tenant_id                  = "your tenant id"
  subscription_id            = "your subscription_id"
}
---------------------------------------------------------
variable.tf
------------
variable "agent_vm_name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "admin_username" { type = string }
variable "admin_password" { type = string }
variable "vm_size" { type = string }
------------------------------------------------------------
terraform.tfvars
----------------
location            = "Central India"
resource_group_name = "rg-devops"
agent_vm_name       = "agent-vm"
admin_username      = "shubham"
admin_password      = "password@123"
vm_size             = "Standard_D2s_v3"
----------------------------------------------------------
### Retrive Resource group
data "azurerm_resource_group" "rg-devops" {
  name = "rg-devops"
}

### Retrive ACR Vnet Id
data "azurerm_virtual_network" "agent-vnet" {
  name                = "agent-vnet"
  resource_group_name = data.azurerm_resource_group.rg-devops.name
}
### Retrive ACR subnet Id
data "azurerm_subnet" "agent-subnet" {
  name                 = "agent-subnet"
  virtual_network_name = "agent-vnet"
  resource_group_name  = data.azurerm_resource_group.rg-devops.name
}
##Create Public IP
resource "azurerm_public_ip" "public_ip" {
  name                = "agentip"
  resource_group_name = data.azurerm_resource_group.rg-devops.name
  location            = var.location
  allocation_method   = "Dynamic"
}
resource "azurerm_network_interface" "main" {
  name                = "agent-nic"
  resource_group_name = data.azurerm_resource_group.rg-devops.name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.agent-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}
resource "azurerm_network_security_group" "nsg" {
  name                = "ssh_nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg-devops.name

  security_rule {
    name                       = "allow_ssh_sg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow_publicIP"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
resource "azurerm_linux_virtual_machine" "main" {
  name                            = var.agent_vm_name
  resource_group_name             = data.azurerm_resource_group.rg-devops.name
  location                        = var.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.main.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}
data "azurerm_public_ip" "public_ip" {
  name                = azurerm_public_ip.public_ip.name
  resource_group_name = data.azurerm_resource_group.rg-devops.name
  depends_on          = [azurerm_linux_virtual_machine.main]
}

output "ip_address" {
  value = data.azurerm_public_ip.public_ip.ip_address
}
=============================================================================================================================
script.sh
-----------
#!/bin/bash

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
sudo usermod -aG docker shubham
sudo systemctl enable docker
sudo systemctl start docker
sudo chmod 666 /var/run/docker.sock
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
sudo apt-get update
# Commands to install the self-hosted agent
curl -o vsts-agent-linux-x64.tar.gz https://vstsagentpackage.azureedge.net/agent/3.234.0/vsts-agent-linux-x64-3.234.0.tar.gz
mkdir myagent
tar zxvf vsts-agent-linux-x64.tar.gz -C myagent
chmod -R 777 myagent
# Configuration of the self-hosted agent
cd myagent
./config.sh --unattended --url your organizations url --auth pat --token your pat token --pool Default --agent aksagent --acceptTeeEula
# Start the agent service
sudo ./svc.sh install
sudo ./svc.sh start
exit 0


=============================================================================================================================
## Install Docker and Configure Self-Hosted Agent
resource "null_resource" "install_docker" {
  provisioner "remote-exec" {
    inline = ["${file("\\script.sh")}"]
    #inline = ["${file("D:\\Nagarro\\Pramotions\\InfrastructureCode\\VM\\script.sh")}"]
    connection {
      type     = "ssh"
      user     = azurerm_linux_virtual_machine.main.admin_username
      password = azurerm_linux_virtual_machine.main.admin_password
      host     = data.azurerm_public_ip.public_ip.ip_address
      timeout  = "10m"
    }
  }
}
=========================================================================================================
variable.tf
-------------
variable "RESOURCE_GROUP_NAME" {
  type        = string
  description = "Resource group"
}

variable "APP_GATEWAY_NAME" {
  type        = string
  description = "Application name. Use only lowercase letters and numbers"

}

variable "LOCATION" {
  type        = string
  description = "Azure region where to create resources."
}

variable "VIRTUAL_NETWORK_NAME" {
  type        = string
  description = "Virtual network name. This service will create subnets in this network."
}

variable "APPGW_PUBLIC_IP_NAME" {
  type        = string
  description = "PUBLIC IP. This service will create subnets in this network."
}
===========================================================================================================
applicationgateway.main.tf
----------------------------
# Subscription ID is required for AGIC
data "azurerm_subscription" "current" {}

data "azurerm_subnet" "appgw-subnet" {
  name                 = "appgw-subnet"
  virtual_network_name = var.VIRTUAL_NETWORK_NAME
  resource_group_name  = var.RESOURCE_GROUP_NAME
}

data "azurerm_resource_group" "rg-devops" {
  name = "rg-devops"
}
#
# Application Gateway
locals {
  backend_address_pool_name      = "${var.VIRTUAL_NETWORK_NAME}-beap"
  frontend_port_name             = "${var.VIRTUAL_NETWORK_NAME}-feport"
  frontend_ip_configuration_name = "${var.VIRTUAL_NETWORK_NAME}-feip"
  http_setting_name              = "${var.VIRTUAL_NETWORK_NAME}-be-htst"
  http_listener_name             = "${var.VIRTUAL_NETWORK_NAME}-httplstn"
  request_routing_rule_name      = "${var.VIRTUAL_NETWORK_NAME}-rqrt"
}

# Public IP
resource "azurerm_public_ip" "public_ip" {
  name                = var.APPGW_PUBLIC_IP_NAME
  resource_group_name = var.RESOURCE_GROUP_NAME
  location            = var.LOCATION
  allocation_method   = "Static"
  sku                 = "Standard"
  #domain_name_label   = var.domain_name_label # Maps to <domain_name_label>.<region>.cloudapp.azure.com
}

# Application gateway
resource "azurerm_application_gateway" "appgateway" {
  name                = var.APP_GATEWAY_NAME
  resource_group_name = var.RESOURCE_GROUP_NAME
  location            = var.LOCATION

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = data.azurerm_subnet.appgw-subnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }
  frontend_port {
     name = "httpsPort"
     port = 443
   }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = local.http_listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.http_listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = "100"
  }
  depends_on = [azurerm_public_ip.public_ip]

  lifecycle {
    ignore_changes = [
      tags,
      backend_address_pool,
      backend_http_settings,
      probe,
      identity,
      request_routing_rule,
      url_path_map,
      frontend_port,
      http_listener,
      redirect_configuration
    ]
  }
}
==================================================================
azure_front_door.main.tf
----------------------------
data "azurerm_application_gateway" "appgateway" {
  name                = "ApplicationGateway1"
  resource_group_name = var.RESOURCE_GROUP_NAME
}

data "azurerm_public_ip" "appgwpublicip" {
  name                = "appgwpublicip"
  resource_group_name = var.RESOURCE_GROUP_NAME
}

resource "random_id" "front_door_endpoint_name" {
  byte_length = 2
}

locals {
  front_door_profile_name      = "MyFrontDoor"
  front_door_endpoint_name     = "afd-${lower(random_id.front_door_endpoint_name.hex)}"
  front_door_origin_group_name = "MyOriginGroup"
  front_door_origin_name       = "MyAppServiceOrigin"
  front_door_route_name        = "MyRoute"
}

resource "azurerm_cdn_frontdoor_profile" "my_front_door" {
  name                = local.front_door_profile_name
  resource_group_name = var.RESOURCE_GROUP_NAME
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "my_endpoint" {
  name                     = local.front_door_endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
}

resource "azurerm_cdn_frontdoor_origin_group" "my_origin_group" {
  name                     = local.front_door_origin_group_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "app_gateway_origin" {
  name                          = "my-app-gateway-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group.id

  enabled                        = true
  host_name                      = data.azurerm_public_ip.appgwpublicip.ip_address
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = data.azurerm_public_ip.appgwpublicip.ip_address # Replace with the host header of your Application Gateway
  priority                       = 1                  # Set the priority according to your needs
  weight                         = 1000               # Adjust weight if needed
  certificate_name_check_enabled = false               # Enable/disable certificate name check as needed
}




resource "azurerm_cdn_frontdoor_route" "my_route" {
  name                          = local.front_door_route_name
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.app_gateway_origin.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpOnly"
  link_to_default_domain = true
  https_redirect_enabled = false
}
