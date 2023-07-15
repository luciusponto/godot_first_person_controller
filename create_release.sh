#!/bin/sh

################################################################################

# Constants
MAJOR_ARG=--major
MINOR_ARG=--minor
PATCH_ARG=--patch

INI_FILE=create_release.ini

show_ini_sample () {
	echo -e "It should include the following entries:"
	echo -e "PREFIX, RELEASES_DIR, PATHS_TO_INCLUDE\n\nExample:\n"
	echo -e "PREFIX=first_person_controller"
	echo -e "RELEASES_DIR=./releases"
	echo -e "PATHS_TO_INCLUDE=dir1 dir2 file1"
	exit 1
}

show_ini_contents_help () {
	echo -e "One or more entries missing from $INI_FILE\n"
	show_ini_sample
}

show_ini_missing_help () {
	echo -e "INI_FILE file not found in current directory.\n\n"
	show_ini_sample
}

find_latest_release () {
	res=$(ls -1 $RELEASES_DIR | sed -e "s/.*v//" -e "s/\.zip//" | sort -V -r | head -n1)
	echo $res
	echo "$res" | grep -e "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" > /dev/null
	return $?
}

parse_version () {
	echo $1 | grep -e "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" > /dev/null
	if [ $? -eq 0 ]; then
		echo "$1"; return 0; fi
		
	latest=$(find_latest_release)
	
	if [ $? -ne 0 ]; then
		return 2
	fi

	major=$(echo $latest | grep -oe "^[0-9]*")
	minor=$(echo $latest | grep -oe "\.[0-9][0-9]*\." | sed -e "s/\.//g")
	patch=$(echo $latest | grep -oe "\.[0-9]*$" | sed -e "s/\.//g")
	
	if [ "$1" == "$MAJOR_ARG" ]; then
		major=$(( $major + 1 ))
		minor=0
		patch=0
	elif [ "$1" == "$MINOR_ARG" ]; then
		minor=$(( $minor + 1 ))
		patch=0
	elif  [ "$1" == "$PATCH_ARG" ]; then
		patch=$(( $patch + 1 ))
	else
		return 1
	fi
	
	echo "a$major.$minor.$patch"
	return 0
}

if [ ! -f $INI_FILE ]; then
	show_ini_missing_help
fi
	
source ./$INI_FILE

if [ "$PREFIX" == "" ] || [ "$RELEASES_DIR" == "" ] || [ "$PATHS_TO_INCLUDE" == "" ]; then
	show_ini_contents_help
	exit 1
fi

version=$(parse_version $1)
ret=$?

if [ $ret -eq 2 ]; then
	echo -e "\nError: cannot automatically increment version - no other release found."
	echo "Please supply as argument a semantic version, like 1.0.0"
	exit 1
elif [ $ret -ne 0 ]; then
	echo -e "\nError: missing argument\n"
	echo -e "Please supply as argument a semantic version, like 1.0.0"
	echo -e "or automatically increment the latest version number with one of:\n"
	echo -e "--major\n--minor\n--patch"
	exit 1
fi

echo $version | grep -e "^a" > /dev/null
if [ $? -eq 0 ]; then
	version=$(echo $version | sed -e "s/^a//")
	echo -e "\nNew version automatically generated with $1 argument: $version"
#else
#	echo -e "\nSpecified version: $1"
fi

if [ ! -d $RELEASES_DIR ]; then
	echo -e "\nError: $RELEASES_DIR directory not found."
	echo -e "\nPlease create the directory or specify another one in $INI_FILE.\n"
	exit 1
fi

which 7z > /dev/null; if [ $? -ne 0 ]; then
	echo "7z not found. Please install or add to system path."; exit 1; fi

DEST=$RELEASES_DIR/$PREFIX-v$version.zip

if [ -f $DEST ]; then
	echo -e "\nError: file already exists.\nCould not create $DEST"; exit 1; fi

echo $PATHS_TO_INCLUDE | xargs 7z a -tzip -mx1 $DEST

if [ $? -eq 0 ]; then
	echo -e "\n\nSUCCESS\n\nRelease created at:\n$DEST"
	else echo -e "\n\nFAILURE\n\nFailed to create release file"; fi
