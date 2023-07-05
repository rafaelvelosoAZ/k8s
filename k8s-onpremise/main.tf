resource "azurerm_resource_group" "rg" {
  name     = "kubernetes-resources"
  location = "eastus"
}

resource "azurerm_network_security_group" "sg" {
  name                = "kubernetes-security-group"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "sg" {
  name                        = "test123"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.sg.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "kubernetes-network"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "aks"
  }
}

resource "azurerm_subnet" "snet" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.snet.id
  network_security_group_id = azurerm_network_security_group.sg.id
}
################ Kuber NODE ########################################
resource "azurerm_public_ip" "pip" {
  count               = 2
  name                = "pip-vm-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "node" {
  count = 2

  name                = "kuber-node-${count.index}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(concat(azurerm_public_ip.pip.*.id, [""]), count.index)
  }
}

resource "azurerm_linux_virtual_machine" "node" {
  count = 2

  name                = "kuber-node-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.node[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202201040"
  }

  tags = var.tags-worker
}

resource "azurerm_managed_disk" "data-disk" {
  count                = 2
  name                 = "disk-vm-${count.index}"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  storage_account_type = "Standard_LRS"
  disk_size_gb         = "100"
  create_option        = "Empty"
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk-attach" {
  count = 2

  managed_disk_id    = azurerm_managed_disk.data-disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.node[count.index].id
  lun                = count.index
  caching            = "ReadWrite"
}
################ Kuber Master ########################################
resource "azurerm_public_ip" "pip-master" {
  count = 1

  name                = "pip-vm-master-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "master" {
  count = 1

  name                = "kuber-master-${count.index}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(concat(azurerm_public_ip.pip-master.*.id, [""]), count.index)
  }
}

resource "azurerm_linux_virtual_machine" "master" {
  count = 1

  name                = "kuber-master-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.master[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202201040"
  }
  tags = var.tags-master
}

resource "azurerm_managed_disk" "data-disk-master" {
  count = 1

  name                 = "disk-vm-master-${count.index}"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  storage_account_type = "Standard_LRS"
  disk_size_gb         = "100"
  create_option        = "Empty"
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk-attach-master" {
  count = 1

  managed_disk_id    = azurerm_managed_disk.data-disk-master[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.master[count.index].id
  lun                = count.index
  caching            = "ReadWrite"
}

/* ############################HA Proxy##########################################
resource "azurerm_public_ip" "pip-ha-proxy" {
  count = 1

  name                = "pip-ha-proxy-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "ha-proxy" {
  count = 1

  name                = "ha-proxy-${count.index}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(concat(azurerm_public_ip.pip-ha-proxy.*.id, [""]), count.index)
  }
}

resource "azurerm_linux_virtual_machine" "ha-proxy" {
  count = 1

  name                = "ha-proxy-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.ha-proxy[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202201040"
  }
  tags = var.tags-master
}

resource "azurerm_managed_disk" "ha-proxy" {
  count = 1

  name                 = "disk-vm-ha-proxy-${count.index}"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  storage_account_type = "Standard_LRS"
  disk_size_gb         = "100"
  create_option        = "Empty"
}

resource "azurerm_virtual_machine_data_disk_attachment" "ha-proxy" {
  count = 1

  managed_disk_id    = azurerm_managed_disk.ha-proxy[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.ha-proxy[count.index].id
  lun                = count.index
  caching            = "ReadWrite"
} */
