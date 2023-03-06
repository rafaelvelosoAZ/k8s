#!/usr/bin/env bash

sudo apt install -y containerd.io

sudo mkdir -p /etc/containerd

sudo containerd config default > /etc/containerd/config.toml

sudo systemctl enable containerd

sudo systemctl restart containerd