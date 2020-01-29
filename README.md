## Technical test

The goal of this repository is to make available my solution for the technical test.

At the moment of this writing, the [App](http://35.188.27.228) is being served at http://35.188.27.228

In order to replicate this demo on your own, this repository contains the necessary details to do so.

## Solution design
1. The App was developed using the Dancer framework for the Perl language and a Postgres DB.
The DB and App were containerized as part of my plan for easy scaling/deployment (time constraints 
prevented me from completing this portion).

2. The App is deployed to a VM on Google Cloud Platform using docker-compose to bring up the containers
for Database and Web Application.

3. The ansible playbook uses a google service account to connect to the GCP project and performs these tasks:
- Reserves a public ("External") IP
- Creates a small virtual machine running Debian
- Installs docker and some pre requisites
- Copies the docker-compose.yml for the Web App 
- Start the containers
