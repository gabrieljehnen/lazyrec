#!/bin/bash

display_banner() {
    echo "====================================================="
    figlet -f slant LAZYREC
    echo "====================================================="
    echo "Versão: 1.0"
    echo "Desenvolvido por Gabriel Jehnen"
    echo -e "=====================================================\n"
}

display_banner
TARGETS_LIST=$1

#if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
#    echo "Usage: $0 <targets_file.txt> [foldername (optional)]"
#    exit 1
#elif ! test -f "$TARGETS_LIST" -o -r "$TARGETS_LIST"; then
#  echo "The first argument must be a text file."
#  echo "Usage: $0 <targets_file.txt> [foldername (optional)]"
#  exit 1
#fi

FOLDER_NAME=${2:-"lazyrec"}
USERNAME=$(whoami)
FOLDER_PATH=/home/$USERNAME/$FOLDER_NAME

mkdir $FOLDER_PATH
cp $1 $FOLDER_PATH
cd $FOLDER_PATH
mkdir patterns

download_patterns(){
    cd ~; mkdir .gf; cd .gf;
    git clone https://github.com/1ndianl33t/Gf-Patterns.git;
    cd Gf-Patterns; mv * ..; rm -r Gf-Patterns;
    cd $FOLDER_PATH;
}

check_golang(){
    if ! $(which go &> /dev/null); then
	sudo apt install golang-go;
    fi
}

install_tools(){
    author="$1"
    shift
    for tool in "$@"; do
        tool_name=$(echo $tool | awk -F/ '{print $NF}')
        if ! $(which $tool_name &> /dev/null) ; then
	    echo $tool_name
	    if $tool_name == "nmap"; then
		sudo apt install -y nmap
		continue
	    elif $tool_name == "httprobe"; then
		go install -v "github.com/$author/$tool@master"
		cd ~/go/bin; sudo mv $tool_name /usr/bin
		continue
	    fi
	    echo $tool_name; echo $tool_name
            echo -e "$tool_name não está instalado. Instalando..."
            go install -v "github.com/$author/$tool@latest"
	    cd ~/go/bin; sudo mv $tool_name /usr/bin
        fi
    if ! ls ~/.gf 1> /dev/null 2>&1; then
	download_patterns
    fi
	cd $FOLDER_PATH
    done
}

subdomain_enum(){
    echo -e "Starting Subdomain Enumeration with [Tomnomnom's Assetfinder & Projectdiscovery's Subfinder] (1/6)"
    subfinder -dL $TARGETS_LIST -o subfinder.txt &
    cat $TARGETS_LIST | assetfinder --subs-only > assetfinder.txt &
    wait
    sort -u -o all_subs.txt subfinder.txt assetfinder.txt
    rm subfinder.txt; rm assetfinder.txt
    echo -e "Finished Subdomain Enumeration"
}


probe_http(){
    echo -e "Probing Active Hosts with [Tomnomnom's Httprobe] (2/6)"
    cat all_subs.txt | httprobe > active_urls.txt
    rm all_subs.txt;
    echo -e "Finished Probing Hosts"
}

get_responses(){
    echo "Fetching URLs and collecting Responses with [Tomnomnom's Meg] (3/6)"
    meg --savestatus 200 --delay 10000 / active_urls.txt home
    meg --savestatus 200 --delay 10000 /robots.txt active_urls.txt robots.txt
    meg --savestatus 200 --delay 10000 /.well-known/security.txt active_urls.txt security.txt
    echo "Finished Meg"
}

verify_subtakeover(){
    echo -e "Verifying Urls vulnerable to Subdomain Takeover with [LukaSikic's Subzy] (4/6)"
    subzy run --targets active_urls.txt
    echo -e "Finished Verifying Subs Takeover"
}

port_scan(){
    echo -e "Starting Port Scanning with [Nmap] (5/6)"
    sed -e 's/https\?:\/\///' active_urls.txt > raw_active_urls.txt;
    nmap -iL raw_active_urls.txt --top-ports 30 --exclude-ports 80,443 -open -o open_ports.txt
    echo -e "Finished Port Scanning"
}

gather_urls(){
    pwd
    echo -e "Gathering URLs with [lc's Gau]. This may take a while... (6/6)"
    cat active_urls.txt | gau --threads 3 > gau.txt
    echo -e "Finished Gathering URLs"
}

grep_patterns(){
    echo "Grepping Patterns"
    cat gau.txt | gf xss > patterns/xss.txt
    cat gau.txt | gf sqli > patterns/sqli.txt
    cat gau.txt | gf lfi > patterns/lfi.txt
    cat gau.txt | gf redirect > patterns/redirect.txt
    echo "Finished"
}


# Instale as ferramentas de diferentes autores
install_tools "tomnomnom" "assetfinder" "meg" "httprobe" "gf" "waybackurls"
install_tools "projectdiscovery" "subfinder/v2/cmd/subfinder"
install_tools "lc" "gau/v2/cmd/gau"
install_tools "LukaSikic" "subzy"

check_golang #Checks if golang is installed
install_tools #Download all dependencies
subdomain_enum #Starts Subdomain Enumeration
probe_http #Checks Active URLs
get_responses
#verify_subtakeover #Verifies if a subdomain is vulnerable to Subdomain Takeover
#port_scan #Starts Port Scanning to active hosts
gather_urls #Gets as many URLs as possible
grep_patterns #Extract patterns from gathered URLs

