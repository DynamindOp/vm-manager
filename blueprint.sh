#!/bin/bash

clear

# Colors
RED='\033[0;31m'
GRN='\033[0;32m'
CYN='\033[0;36m'
YEL='\033[1;33m'
NC='\033[0m' # No Color

# Blueprint installation
cd ~/blueprints || { echo -e "${RED}❌ blueprints folder not found!${NC}"; exit 1; }

blueprints=(
  "snowflakes.blueprint"
  "mcplugin.blueprint"
  "loader.blueprint"
  "minecraftplayermanager.blueprint"
  "nightadmin.blueprint"
  "versionchanger.blueprint"
  "huxregister.blueprint"
  "mcmods.blueprint"
  "myhticalui.blueprint"
  "minecrafticonchanger.blueprint"
)
for bp in "${blueprints[@]}"; do
  if [ -f "$bp" ]; then
    mv "$bp" /var/www/pterodactyl/ || { echo -e "${RED}❌ Failed to move $bp${NC}"; continue; }
    cd /var/www/pterodactyl || exit 1
    blueprint -install "$bp" || echo -e "${RED}❌ Failed to install $bp${NC}"
  else
    echo -e "${YEL}⚠️  $bp not found, skipping...${NC}"
  fi
done
