#!/usr/bin/env bash

sudo apt-get update &> /dev/null && sudo apt-get install -y &> /dev/null apt-transport-https &> /dev/null gnupg2 &> /dev/null

sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - &> /dev/null

sudo echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list &> /dev/null

sudo apt-get update &> /dev/null

sudo apt-get install -y kubelet &> /dev/null kubeadm &> /dev/null kubectl &> /dev/null

sudo swapoff -a &> /dev/null

sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab &> /dev/null