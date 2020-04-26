FROM jenkins/jenkins

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

COPY security.groovy /usr/share/jenkins/ref/init.groovy.d/security.groovy

RUN /usr/local/bin/install-plugins.sh locale workflow-aggregator ssh-slaves blueocean kubernetes-cd prometheus slack

COPY locale.xml /var/jenkins_home/locale.xml
COPY jenkins.plugins.slack.SlackNotifier.xml /var/jenkins_home/jenkins.plugins.slack.SlackNotifier.xml
