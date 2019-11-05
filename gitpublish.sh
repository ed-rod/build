#!/bin/bash

#------------------------------------------------------------------------------
# Publish script. Must be run from within the directory that has the POM file
# that is being built.
#------------------------------------------------------------------------------

# First of all, ensure that we don't have any outgoing changes
git reset --hard

# Get the current version
CurVersion="1.0.0"
LineMatches=$(grep "\-SNAPSHOT" pom.xml)
Regex="<version>(.*)-SNAPSHOT</version>"
if [[ $LineMatches  =~ $Regex ]]; then
        CurVersion=${BASH_REMATCH[1]}
fi
echo Building version $CurVersion

# Get the Git branch version
LineMatches=$(git branch | grep "*")
Regex="\* (.*)"
if [[ $LineMatches  =~ $Regex ]]; then
        BranchName=${BASH_REMATCH[1]}
fi
echo Current branch $BranchName

# Get the last number and increment by 1
Regex="(.*)\.(.*)\.(.*)"
if [[ $CurVersion  =~ $Regex ]]; then
        MajorVersion=${BASH_REMATCH[1]}
        MinorVersion=${BASH_REMATCH[2]}
        BuildVersion=${BASH_REMATCH[3]}
fi

CurBranchName=${MajorVersion}.${MinorVersion}
NewBuildVersion=$((BuildVersion + 1))
NewVersion=${MajorVersion}.${MinorVersion}.${NewBuildVersion}
CurVersionSnapshot=${CurVersion}-SNAPSHOT
NextVersionSnapshot=${NewVersion}-SNAPSHOT


# Now we need to replace all the snapshot versions in the POM files with the CurVersion
Replacement="s/${CurVersionSnapshot}/${CurVersion}/g"
find . -type f \( -name pom.xml -o -name version.json \) -exec sed -i "$Replacement" {} \;

#-----------------------------------------------------------------------------
# Initial build. Check to see that all components build before we attempt
# to deploy any of them
#-----------------------------------------------------------------------------
# Try building the component
mvn clean test
if [ $? -eq 0 ]; then
        # Try deploying it to Nexus
        mvn deploy

        if [ $? -eq 0 ]; then
                # Now that it's been deployed, create a tag
                mvn clean
                git checkout -b build_${CurVersion}
                git add .
                git commit -m "Creating tab for version $CurVersion"
                git push -u origin build_${CurVersion}
                git checkout master
		git merge --no-edit build_${CurVersion}
		git checkout $BranchName
		git merge --no-edit build_${CurVersion}

                # Now we need to update all POM files so we can replace the snapshot version with the new version
                git reset --hard

                # Ensure we have the latest copy (bring in new tag)
                git pull

                # Now we increment the revision in the POM file
                Replacement="s/${CurVersionSnapshot}/${NextVersionSnapshot}/g"
                find . -type f \( -name pom.xml -o -name version.json \) -exec sed -i "$Replacement" {} \;

                # Commit that, too
                git add .
                git commit -m "Updating to version $NextVersionSnapshot"
                git push
                git pull
        else
                mvn clean
                git reset --hard
        fi

else
        mvn clean
        git reset --hard
fi




