#!/usr/bin/env bash
#!/bin/bash
set -e

#
# Core check
#

TEST_FAILURE=FALSE

# Check if the internet connection is working
wget -q --tries=2 --timeout=5 --spider http://google.com
if [[ $? -eq 0 ]]; then
        echo "Internet connection is available: PASSED"
else
        echo "Internet connection is available: FAILED"
        TEST_FAILURE=TRUE
fi

# Check if /usr/local/ directory exists & writable ( needed for installing GPDB software )
if [ -d /usr/local ]; then
     echo "Directory /usr/local/ exists: PASSED"
else
    echo "Directory /usr/local/ exists: FAILED"
    TEST_FAILURE=TRUE
fi

if [ -w /usr/local ]; then
     echo "Directory /usr/local/ writable: PASSED"
else
    echo "Directory /usr/local/ writable: FAILED"
    TEST_FAILURE=TRUE
fi

# Check if the BASE DIRECTORY exists & writable
BASE_DIR=`grep BASE_DIR config.yml | cut -d':' -f2 | awk '{print $1}'`
if [ -d "$BASE_DIR" ]; then
     echo "Base directory $BASE_DIR exists: PASSED"
else
    echo "Base directory $BASE_DIR exists: FAILED"
    TEST_FAILURE=TRUE
fi

if [ -w "$BASE_DIR" ]; then
     echo "Directory $BASE_DIR writable: PASSED"
else
    echo "Directory $BASE_DIR writable: FAILED"
    TEST_FAILURE=TRUE
fi


# Check if the hostname is reachable
host=`grep MASTER_HOST config.yml | cut -d':' -f2 | awk '{print $1}'`
ping -c 1 $host &>/dev/null
if [ $? -eq 0 ]; then
    echo "Host $host can be reached: PASSED"
else
   echo "Host $host can be reached: FAILED"
   TEST_FAILURE=TRUE
fi

# If any one of the precheck failed, then exit the setup process.
if [ $TEST_FAILURE == "TRUE" ]; then
    echo "Pre check failed, exiting...."
fi

#
# Download and install GO Binaries.
#

# Setting up go version to download
VERSION="1.7.4"
DFILE="go$VERSION.linux-amd64.tar.gz"

# If the version of go already exit then uninstall it
if [ -d "$HOME/.go" ]; then
        rm -rf $HOME/.go
fi

# Downloading the go tar file
echo "Downloading the GO binary $DFILE ..., please wait might take few minutes based on your internet connection"
wget https://storage.googleapis.com/golang/$DFILE -O /tmp/go.tar.gz -q
if [ $? -ne 0 ]; then
    echo "Download failed! Exiting."
    exit 1
fi

# Extracting the file
echo "Extracting ..."
tar -C "$HOME" -xzf /tmp/go.tar.gz
mv "$HOME/go" "$HOME/.go"
chown -R gpadmin:gpadmin "$HOME/.go"

#
# Update environment information
#

# Updating the bashrc with the information of GOROOT.
if grep -q "GOROOT" "$HOME/.bashrc";
then
    echo "GOROOT binaries location is already updated on the .bashrc file"
else
    touch "$HOME/.bashrc"
    {
        echo '# Golang binaries'
        echo 'export GOROOT=$HOME/.go'
        echo 'export PATH=$PATH:$GOROOT/bin'
    } >> "$HOME/.bashrc"
fi

# Update bashrc with the information of GOPATH.
if grep -q "GOPATH" "$HOME/.bashrc";
then
    echo "GOPATH location is already updated on the .bashrc file"
else
    pwd=`pwd`
    touch "$HOME/.bashrc"
    {
        echo '# GOPATH location'
        echo 'export GOPATH='${pwd}
        echo 'export PATH=$PATH:$GOPATH/bin'
    } >> "$HOME/.bashrc"
fi

# Remove the downloaded tar file
rm -f /tmp/go.tar.gz

#
# Upgrading the code (if any)
#

echo "Pulling newer version of the code"
if [ -f $HOME/.config.yml ]; then
    cp config.yml /tmp/config.yml
fi

if [ -f /tmp/config.yml ]; then
    mv /tmp/config.yml $HOME/.config.yml
else
    cp config.yml $HOME/.config.yml
fi

#
# Removed the gopkg.in/yaml.v2 folder
#

echo "Removing src / pkg directory to pull in the newer version of the code"
rm -rf src/
rm -rf pkg/

#
# Download program dependencies
#

echo "Downloading program dependencies"

# go-logging package
# YAML package
source "$HOME/.bashrc"
go get github.com/op/go-logging
if [ $? -ne 0 ]; then
    echo "Download failed of dependencies (go-logging) package failed. Exiting....."
    exit 1
fi

# YAML package
source "$HOME/.bashrc"
go get gopkg.in/yaml.v2
if [ $? -ne 0 ]; then
    echo "Download failed of dependencies (yaml.v2) package failed. Exiting....."
    exit 1
fi

# gpdb source code
source "$HOME/.bashrc"
go get github.com/ielizaga/piv-go-gpdb
if [ $? -ne 0 ]; then
    echo "Download failed of dependencies (piv-go-gpdb) package failed. Exiting....."
    exit 1
fi

#
# Changing the owner to gpadmin:gpadmin
#
chown -R gpadmin:gpadmin /home/gpadmin

#
# Build go executable file.
#

echo "Compiling the program... "
# Compile the program
go build $GOPATH/src/github.com/ielizaga/piv-go-gpdb/gpdb.go
if [ $? -ne 0 ]; then
    echo "Cannot build gpdb executable, exiting ....."
    exit 1
fi

# move the binary file to bin directory
if [ ! -d bin ]; then
    mkdir -p $GOPATH/bin/
fi

# move it to bin directory (forcefully, no need to prompt)
mv -f gpdb $GOPATH/bin/

#
# Changing the owner to gpadmin:gpadmin
#
chown -R gpadmin:gpadmin /home/gpadmin

#
# Success message.
#

echo "GPDBInstall Script has been successfully installed"
echo "Config file is cached at location: "$HOME/.config.yml
echo "Please close this terminal and open up a new terminal to set the environment"