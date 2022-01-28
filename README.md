# k8s-scripts

Various scripts for automated k8s cluster bootstrap and management with fluxcd.

Scripts are created and tested in Linux (Ubuntu) environment but should work on any system with Bash and basic tools installed to default executable PATH.

Requirements

1. Running 'empty' k8s cluster
2. Configured and working local environment with kubectl connecting to the k8s cluster by default
3. Commandline tools installed and available in executable PATH
  - pwgen
  - kubectl
  - fluxcd - https://fluxcd.io/docs/installation/
  - kustomize - https://kubectl.docs.kubernetes.io/installation/kustomize/
  - git
  - yq - https://github.com/mikefarah/yq/
4. Bash

Initial setup:

1. Create config file for configuration settings and backup, ie. ```mkdir ~/.tigase-flux```. If you wish to put config in a different location, set `TIG_CLUSTER_HOME` variable to point to this location. This will be used as `CONFIG` variable.
2. Copy entire `envs` folder to ${CONFIG}/envs: ```cp -rv envs ${CONFIG}/```
3. Edit `cluster.env` file. Typically cluster name and github credentials must be provided. The rest can be left to defaults.

Usage:

The main script to bootstrap fluxcd on k8s custer with all basic services is `cluster-bootsrap.sh`. Normally if the environment is correctly configured and tested this is all that needs to be run.
It may take a few minutes but everything is setup automatically with no input from the user.

However, on a fresh system, it is recommended to run bootstrap scripts manually one by one. `-q` option can be added to the script for fully automated execution.
1. `flux-bootstrap.sh` - flux bootstrap, git repository setup and creating basic repo structure
2. `cluster-common-sources.sh` - deploying helm sources to flux system on k8s cluster
3. `cluster-sealed-secrets.sh`
4. `cluster-kubernetes-dashboard.sh`
5. `cluster-ingress-nginx.sh`
6. `cluster-cert-manager.sh`
7. `cluster-longhorn.sh`
8. `cluster-kube-prometheus-stack.sh`
9. `cluster-loki-stack.sh`

