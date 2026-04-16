# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**anyInstall** is a collection of tool installation scripts (工具安装脚本). The repository is in its early stages with no scripts added yet.

## Repository Structure

One folder per tool. Each folder contains:
- The installation script(s) for that tool
- A `README.md` explaining how to download the script and run it to install the tool

Example layout:
```
anyInstall/
├── git/
│   ├── install.sh
│   └── README.md
├── node/
│   ├── install.sh
│   └── README.md
└── ...
```

Each tool's README should show the minimal one-liner a user needs to download and execute the script (e.g. via `curl` or `wget`), followed by any post-install steps.
