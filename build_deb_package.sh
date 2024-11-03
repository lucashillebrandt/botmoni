#!/bin/bash
# build_deb_package.sh - A helper script to build a debian package for quick installation on Ubuntu Servers..
# Author: Lucas Hillebrandt
# Version: 1.3
# LICENSE: GPLv3

#TODO: Instead of a build file, convert this process into a CI process that can be managed by Jenkins or any other CI tool. 

#######################################
# Updates the changelog with the provided information.
#
# Args:
#   version: The new version number for the package.
#   full_name: The full name of the person making the change.
#   email: The email address of the person making the change.
#   changelog: The changelog message.
#
# Returns:
#   0 if the command was successful, 1 otherwise.
#######################################
_update_changelog() {
    local version="$1"
    local full_name="$2"
    local email="$3"
    local changelog="$4"

    # Set the required environment variables.
    export DEBFULLNAME="$full_name"
    export DEBEMAIL="$email"

    # Update the changelog.
    dch -v ${version} --distribution noble "$changelog" -c ./debian/changelog

    # Check if the command was successful.
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Could not update changelog. Exiting."
        exit 5
    fi
}

#######################################
# Publishes a new version of the application on git.
#
# Args:
#   git_folder: The path to the git repository.
#   tag: The version number to publish.
#
# Returns:
#   0 if the command was successful, 1 otherwise.
#######################################
_publish_git_tag() {
    local git_folder="$1"
    local tag="$2"

    # Change to the provided git folder.
    cd "$git_folder"

    # Commit all changes.
    git add .
    git commit -m "Launches tag $tag"

    # Push all changes to the origin.
    git push

    # Tag the commit with the provided version.
    git tag -a "$tag" -m "Launches tag $tag"

    # Push the tag to the origin.
    git push origin "$tag"
}

#######################################
# Builds a debian package for the application.
#
# Args:
#   version: The new version number for the package.
#   full_name: The full name of the person making the change.
#   email: The email address of the person making the change.
#   changelog: The changelog message.
#######################################
_build() {
    if [[ $arg_skip_changelog -ne 1 ]]; then
        version="$1"
        full_name="$2"
        email="$3"
        changelog="$4"

        if [[ -z $version ]]; then
            echo "[ERROR] Version is missing"
            exit 1
        fi

        if [[ -z $full_name ]]; then
            echo "[ERROR] Name is missing"
            exit 2
        fi

        if [[ -z $email ]]; then
            echo "[ERROR] Email is missing"
            exit 3
        fi

        if [[ -z $changelog ]]; then
            echo "[ERROR] Changelog message is missing"
            exit 4
        fi

        # Update the changelog.
        _update_changelog "$version" "$full_name" "$email" "$changelog"
    fi

    # Create a temporary build folder.
    build_dir=$(mktemp -d)
    build_folder=$(pwd)
    current_tag=$(cat debian/changelog | head -n 1 | cut -d '(' -f2 | cut -d ')' -f1)
    tag_folder="$build_folder/tags/$current_tag"

    if [[ ! -d $tag_folder ]]; then
        # Create the tag folder if it doesn't exist.
        mkdir -p $tag_folder
    fi

    echo $tag_folder

    # Copy all files to the build folder.
    cp -r $build_folder/* $build_dir

    cd $build_dir

    # Create the required folders.
    mkdir -p debian/usr/share/botmoni/

    # Copy all files to the build folder.
    cp -r $build_folder/* $build_dir/debian/usr/share/botmoni/

    # Define the files to remove from the build folder.
    files=("debian" ".env.example" "tests" ".editorconfig" ".git*" "README.md" "bin" "ci" "virus_total" ".env" "build_deb_package.sh" "tags" )

    # Remove all the defined files from the build folder.
    for item in ${files[@]}; do
        if [[ -f "debian/usr/share/botmoni/$item" || -d "debian/usr/share/botmoni/$item" ]]; then
            rm -rf $build_dir/debian/usr/share/botmoni/$item
        fi
    done

    # Create the required folders.
    mkdir -p debian/etc/botmoni/

    # Copy the .env.example file to the /etc/botmoni folder.
    cp $build_folder/.env.example debian/etc/botmoni/

    # Build the deb package.
    debuild -us -uc -i &> /dev/null

    if [[ $? -eq 0 && -f /tmp/botmoni_${current_tag}_all.deb ]]; then
        # Move the package to the tag folder.
        mv /tmp/botmoni_${current_tag}_all.deb $tag_folder

        # Publish the new tag on git.
        _publish_git_tag $build_folder $current_tag
    fi
}

_parse_args() {
    args=$(echo "$@" | egrep -o "\-\-(.*)( |=(.*)|$)")

    for arg in ${args[@]}; do
        echo $arg | egrep -q "^--" || continue

        arg=$(echo $arg | sed "s/^--//g" | sed "s/-/_/g")

        if echo $arg | grep -q "="; then
            name=$(echo $arg | cut -d= -f1)
            value=$(echo $arg | cut -d= -f2)
        else
            name=$arg
            value="1"
        fi

        name=$(echo "arg_$name" | sed "s/[^0-9a-zA-Z_]//g")

        eval "$name=\$value"
    done
}

_parse_args $*

case "$1" in
    build)
        eval _build "$2" "\"${3}\"" "$4" "\"$5\"" $stdout
        ;;
    *)
        echo -e "Usage:\n"
        echo -e "build_deb_package.sh build <version> <full_name> <email> <changelog message> [--skip-changelog]"
        ;;
esac
