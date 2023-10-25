#!/bin/bash

#Author: Gabriel Jehnen

TARGETS_LIST=$1
FOLDER_NAME=$2
USERNAME=$(whoami)
FOLDER_PATH=/home/$USERNAME/$FOLDER_NAME

mkdir $FOLDER_PATH
cd $FOLDER_PATH

pwd

configure_gf(){
    cd ~; mkdir .gf; cd .gf;
    git clone https://github.com/1ndianl33t/Gf-Patterns.git;
    cd Gf-Patterns; mv * ..; rm -r Gf-Patterns;
}

install_tools() {
    author="$1"
    shift
    for tool in "$@"; do
        tool_name=$(echo $tool | awk -F/ '{print $NF}')
        if ! command -v "$tool_name" &> /dev/null; then
            if $tool_name == "naabu"; then
                sudo apt install -y libcap-dev
            elif $tool_name == "gf"; then
                configure_gf
            fi
            echo "$tool_name não está instalado. Instalando..."
            go install -v "github.com/$author/$tool@latest"
        fi
    done
}

subdomain_enum(){
    echo -e "Starting Subdomain Enumeration (1/6)\n"
    subfinder -dL $TARGETS_LIST -o subfinder.txt &
    cat $TARGETS_LIST | assetfinder > assetfinder.txt &
    wait
    sort -u -o all_subs.txt subfinder.txt assetfinder.txt
    cat all_subs.txt | httprobe > active_urls.txt
    rm assetfinder.txt; rm subfinder.txt; rm all_subs.txt
    echo -e "Finished Subdomain Enumeration\n"
}

verify_subtakeover(){
    echo -e "Verifying Urls vulnerable to Subdomain Takeover (2/6)\n"
    subzy run --targets active_urls.txt
    echo -e "Finished Verifying Subs Takeover\n"
}

gather_urls(){
    echo -e "Gathering Url's... This may take a while (\n"
    cat active_urls.txt | gau --threads 5 > gau.txt
}

port_scan(){
    echo -e "Starting Port Scanning (3/6)\n"
    sed 's~^https://~~' active_urls.txt > raw_active_urls.txt
    naabu -list raw_active_urls.txt -exclude-ports 80,443 -v -o ports.txt 
    rm raw_active_urls.txt
    echo -e "Finished Port Scanning\n"
}

gf(){
    cat gau.txt | gf xss > possible_xss.txt
}


# Instale as ferramentas de diferentes autores
install_tools "tomnomnom" "assetfinder" "httprobe" "gf" "waybackurls"
install_tools "projectdiscovery" "subfinder/v2/cmd/subfinder" "naabu/v2/cmd/naabu" "katana/v2/cmd/katana"
install_tools "lc" "gau/v2/cmd/gau"
install_tools "PentestPad" "subzy"

subdomain_enum
verify_subtakeover
port_scan
gather_urls
gf

