#!/bin/bash

# Major revision to be used for theme and library.
MAJOR="2"

# Check and update package.json as needed
echo "==> ksa: Checking package.json...";
node ./customizations/update-package-json.js
if [[ $? -ne 0 ]]; then
  exit 1
fi

# Initialize a new theme
read -r -p "==> ksa: Would you like to initialize a new theme? (no): " response
case "$response" in
  [yY][eE][sS]|[yY])
    dirname=${PWD##*/}
    read -e -p "==> ksa: What would you like to call the new theme? ($dirname): " themename
    [ -z "${themename}" ] && themename=$dirname
    if [ ! -d htdocs/wp-content/themes/$themename ]; then
      echo '==> ksa: Cloning kage starter theme into themes directory and removing its .git directory'
      git clone git@github.com:kehittamo/kage.git htdocs/wp-content/themes/$themename
      cd htdocs/wp-content/themes/$themename
      # Try checking out theme by tag.
      TAG="$MAJOR.*"
      LATEST_TAG=`git describe --tags --abbrev=0 --match $TAG 2> /dev/null`
      if [[ -z $LATEST_TAG ]]; then
        echo "==> ksa: Failed to checkout latest theme matching $TAG, using latest commit."
      else
        git checkout $LATEST_TAG
      fi
      rm -rf .git
      cd -
      if [ -f gulp.config.js.example ] && [ ! -f gulp.config.js ]; then
        cp gulp.config.js.example gulp.config.js
        perl -pi -e "s/\b(?!pack)\w*kage\b/$themename/g" gulp.config.js # Don't replace the word package
      fi
      if [ -f bitbucket-pipelines.yml.example ] && [ ! -f bitbucket-pipelines.yml ]; then
        cp bitbucket-pipelines.yml.example bitbucket-pipelines.yml
      fi
      if [ ! $themename = "kage" ]; then
        echo "==> ksa: Setting up theme $themename"
        mv htdocs/wp-content/themes/$themename/lang/kage.pot htdocs/wp-content/themes/$themename/lang/$themename.pot
        sed -i '' -e "s/Kage/$themename/g" htdocs/wp-content/themes/$themename/style.css
        sed -i '' -e "s/\/kage\//\/$themename\//g" package.json # For scripts
      fi
      vagrant ssh -- -t "wp theme activate $themename"
      echo "==> ksa: Theme $themename succesfully initialized and activated."
    else
      echo "==> ksa: Theme $themename directory already exists. Theme not initialized."
    fi
    # If kehittamo's library isn't installed, ask if it should be.
    if [[ -z `composer show kehittamo/kehittamo-seravo-library &> /dev/null` ]]; then
      read -r -p "==> ksa: Would you like to require kehittamo's utility library? (no): " response
      case "$response" in
        [yY][eE][sS]|[yY])
          echo "==> ksa: Requiring kehittamo/kehittamo-seravo-library..."
          composer require "kehittamo/kehittamo-seravo-library:^$MAJOR.0.0"
          ;;
        *)
          echo "==> ksa: Not requiring kehittamo's library."
          ;;
      esac
    fi
    ;;
  *)
    echo '==> ksa: Theme not initialized.'
    ;;
esac


# Actually pull database from production
read -r -p "==> ksa: Actually pull database from production? (no): " response
case "$response" in
  [yY][eE][sS]|[yY])
    vagrant ssh -- -t 'ruby /data/wordpress/customizations/insecure-wp-pull-production-db && ruby /data/wordpress/customizations/create-vagrant-admin'
    ;;
  *)
    echo '==> ksa: Production database not pulled.'
    ;;
esac

# Create default .env.example if not found
if [ ! -f .env.example ]; then
  touch .env.example
  echo "ENABLE_DEBUG=true" >> .env.example
  echo "DISABLE_DEBUG_NOTICES=true" >> .env.example
fi

# Add to .gitignore, if not yet added.
if ! grep -Fxq "# Kehittamo Seravo Addons" .gitignore; then
  echo '==> ksa: Extending .gitignore with Kehittamo Seravo Addons'
  echo "" >> .gitignore
  echo "# Kehittamo Seravo Addons" >> .gitignore
  echo "package.json.example" >> .gitignore
  echo "gulpfile.js" >> .gitignore
  echo "gulp.config.js.example" >> .gitignore
  echo "vagrant-up-customizer.sh" >> .gitignore
  echo ".bitbucket-pipelines.yml.example" >> .gitignore
  echo "customizations/*" >> .gitignore
  echo "!customizations/scripts-project.sh" >> .gitignore
  echo "!customizations/scripts-deployment-tag.sh" >> .gitignore
fi

# Copy ENV if not copied yet
if [ -f .env.example ] && [ ! -f .env ]; then
  echo '==> ksa: Copying .env.example => .env'
  cp .env.example .env
fi

# Yarn
echo '==> ksa: Running yarn'
yarn

# Information
echo '==> ksa: roots/bedrock documentation available at https://roots.io/bedrock/'
echo '==> ksa: kehittamo-seravo-addons documentation available at https://bitbucket.org/kehittamo/kehittamo-seravo-addons'
echo '==> ksa: Start browsersync server & asset watching by running: gulp serve'
