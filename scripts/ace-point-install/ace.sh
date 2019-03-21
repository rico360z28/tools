#!/bin/bash

################################################################################################
# USER CONFIGURATOINS
#

# Define Project and Deploy Diretories
PROJECT_DIR="/home/intel/git"
DEPLOY_DIR="/home/intel"
GATEWAY_START="true"

################################################################################################
# STOP HERE!
# DO NOT EDIT ANY FURTHER
#

# Script Parameters
GATEWAY_GUIDE_VERSION="2018.12.20"
GIT_PATH="https://github.com/intel/rsp-sw-toolkit.git"
DEPLOY_PROJECT="${PROJECT_DIR}/rsp-sw-toolkit/gateway/build/distributions/gateway-1.0.tgz"
INSTALL_DEVTOOLS="openjdk-8-jdk git gradle"
INSTALL_RUNTIME="mosquitto avahi-daemon ntp ssh"
INSTALL_EXTRAS="mosquitto-clients sshpass"

REQUIRED_OS="Ubuntu 18.04.1 LTS"
SCRIPT_VERSION="1.0"
SYSTEM_CHECK="PASS"
GATEWAY_START_DELAY="1m"

BBLUE="\033[0;44m"     # Background Blue
BRED="\033[0;101m"     # Background Red
NC="\033[0m"           # No Color

################################################################################################
# SCRIPT INTRO AND USER ACCEPTANCE
#
clear
printf "\n${BBLUE}Intel RSP SW Toolkit-Gateway Installation Script${NC}\n"
printf "Install Script Based on Document Version: %s \n" "${GATEWAY_GUIDE_VERSION}"
printf "Script Version: %s \n\n" "${SCRIPT_VERSION}"
printf "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, \n"
printf "INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR \n"
printf "PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE \n"
printf "FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR \n"
printf "OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE \n"
printf "OR OTHER DEALINGS IN THE SOFTWARE. \n\n"

while true; do
    read -p "Do you wish to use this script to install and configure your gateway (y or n)? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) printf "Exiting installation script\n"; exit;;
        * ) printf "Please answer yes or no.\n";;
    esac
done

################################################################################################
# PRELIMINARY SYSTEM CHECKS
#

# Check to see if script was executed as root
if ! [ $(id -u) = 0 ]; then
  SYSTEM_CHECK_TEXT+="This script must be run as sudo."
  SYSTEM_CHECK="FAIL"
fi

# Check operating system version
OS_VERSION="$(cat /etc/os-release | grep "PRETTY_NAME" | tr -d '\"')"
OS_VERSION="${OS_VERSION:12:18}"
if ! [ "$REQUIRED_OS" == "$OS_VERSION" ]; then
  SYSTEM_CHECK_TEXT+="You need ${REQUIRED_OS}, you currently have ${OS_VERSION}."
  SYSTEM_CHECK="FAIL"
fi

# Check if computer is on a network
nc -z -w 10 8.8.8.8 53  >/dev/null 2>&1
online=$?
if [ $online -ne 0 ]; then
  SYSTEM_CHECK_TEXT+="Computer needs access to the internet."
  SYSTEM_CHECK="FAIL"
fi

if ! [ "$SYSTEM_CHECK" = "PASS" ]; then
  printf "\n\n${BRED}Preliminary System Check Failure.${NC}\n"
  printf "%s \n" "${SYSTEM_CHECK_TEXT}"
  printf "Exiting Script.\n"
  exit 1
fi

################################################################################################
# USER VALIDATION
#

# Gateway Configuration
#
VALIDATION_TEXT+=$'Project Directory:      '
VALIDATION_TEXT+="${PROJECT_DIR}"
VALIDATION_TEXT+=$'\nDeployment Directory:   '
VALIDATION_TEXT+="${DEPLOY_DIR}"
VALIDATION_TEXT+=$'\nGIT Path:               '
VALIDATION_TEXT+="${GIT_PATH}"
VALIDATION_TEXT+=$'\n'

clear
printf "\n${BBLUE}Intel RSP SW Toolkit-Gateway Installation Script${NC}\n"
printf "Install Script Based on Document Version: %s \n\n" "${GATEWAY_GUIDE_VERSION}"
printf "Please verify the following information:\n"
printf "%s \n" "${VALIDATION_TEXT}"
printf "If the information is incorrect then exit script, edit and restart script. \n"

while true; do
    read -p "Do you want to proceed with the installation (y or n)? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) printf "Exiting installation script\n"; exit;;
        * ) printf "Please answer yes or no.";;
    esac
done

# performing apt-get update and validating internet connection
printf "\n${BBLUE}ACE Point Script:${NC}  Preforming system update"
printf "\n"
sudo apt-get update
if [ $? != 0 ]; then
  # apt-get failed.
  printf "\n${BBLUE}ACE Point Script:{NC}  apt-get update failure, exiting script\n"
  exit 1
fi

printf "\n${BBLUE}ACE Point Script:${NC}  Creating Project Directory: ${PROJECT_DIR}"
printf "\n"
mkdir -p ${PROJECT_DIR}

printf "\n${BBLUE}ACE Point Script:${NC}  Creating Deployment Directory: ${DEPLOY_DIR}"
printf "\n"
mkdir -p ${DEPLOY_DIR}

printf "\n${BBLUE}ACE Point Script:${NC}  Installing Development Tools"
printf "\n"
sudo apt-get -y install ${INSTALL_DEVTOOLS}

printf "\n${BBLUE}ACE Point Script:${NC}  Installing Runtime Packages"
printf "\n"
sudo apt-get -y install ${INSTALL_RUNTIME}

printf "\n${BBLUE}ACE Point Script:${NC}  Installing Extra Packages"
printf "\n"
sudo apt-get -y install ${INSTALL_EXTRAS}

printf "\n${BBLUE}ACE Point Script:${NC}  Cloning project from GITHUB"
printf "\n"
cd ${PROJECT_DIR}
git clone ${GIT_PATH}

printf "\n${BBLUE}ACE Point Script:${NC}  Build an archive suitable for deployment"
printf "\n"
cd "${PROJECT_DIR}/rsp-sw-toolkit/gateway"
gradle buildTar

printf "\n${BBLUE}ACE Point Script:${NC}  Deploy the project"
printf "\n"
cd "${DEPLOY_DIR}"
tar -xf "${DEPLOY_PROJECT}"

printf "${BBLUE}ACE Point Script:${NC}  Generate certificates and keys"
printf "\n"
mkdir -p "${DEPLOY_DIR}/gateway/cache"
cd "${DEPLOY_DIR}/gateway/cache"
"${DEPLOY_DIR}/gateway/gen_keys.sh"

if [ $GATEWAY_START == "true" ]; then
printf "\n${BBLUE}ACE Point Script:${NC}  Installing Extra Packages\n"
printf "\n"
sudo apt-get -y install ${INSTALL_EXTRAS}

printf "\n${BBLUE}ACE Point Script:${NC}  Starting Gateway, please wait"
printf "\n"
gnome-terminal -e "bash -c \"exec /home/intel/gateway/run.sh\"" >/dev/null 2>&1
sleep ${GATEWAY_START_DELAY}

printf "\n${BBLUE}ACE Point Script:${NC}  Configuring Sensors to TEST facility and starting to read"
printf "\n"
sshpass -p 'gwconsole' ssh -oStrictHostKeyChecking=no -p5222 gwconsole@localhost << !
sensor set.facility TEST ALL
scheduler activate.all.sequenced
quit
!

printf "\n${BBLUE}ACE Point Script:${NC}  Opening a terminal to display Events MQTT Messages"
printf "\n"
gnome-terminal -e "bash -c \"exec mosquitto_sub -t rfid/gw/events\"" >/dev/null 2>&1

printf "\n${BBLUE}ACE Point Script:${NC}  Opening a terminal to display raw rfid MQTT Messages"
printf "\n"
gnome-terminal -e "bash -c \"exec mosquitto_sub -t rfid/rsp/data/#\"" >/dev/null 2>&1

fi

printf "\n${BBLUE}ACE Point Script:${NC}  INSTALLATION DONE\n"
printf "\n"
#printf "\nStart the gateway application by executing:\n"
#printf "%s/gateway/run.sh" "${DEPLOY_DIR}"
#printf "\n"
