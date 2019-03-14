#!/bin/sh

#################################################################
# The script does the following as part of the release process.
# If any of the steps fail then the process is aborted. All steps needs to be successful to complete the release
# 1. Run the unit tests.
#   1.1 check is the unit test runs successfully with all the test cases passing
#   1.2 if the unit tests fails exit
# 2. Run integration tests
# 3. Get the latest build of the sdk from master
# 4. Create the new release tag
# 5. push the tag to github
# 6. Update the podspec with the new release version
# 7. validate the podspec
#   7.1 if the validation fails exit
# 8. Push the podspec to cocoapods
# 9. Notify the slack channel about the release
##################################################################

if [ -d "scripts" ]; then
cd scripts/
fi

cd ../src/PrebidMobile/
echo $PWD
echo "Start unit tests"
gem install xcpretty
build_errors_file=build_errors.log
xcodebuild test -project PrebidMobile.xcodeproj -scheme "PrebidMobileTests" -destination 'platform=iOS Simulator,name=iPhone 8 Plus,OS=11.0.1' | xcpretty
if [ "${PIPESTATUS[0]}" -ne "0" ]; then
    echo "Error: xcodebuild failed"; exit 1;
fi
echo "End unit tests"

echo "Start demo app build"
cd ../../example/Swift/PrebidDemo/
echo $PWD
xcodebuild -workspace PrebidDemo.xcworkspace -scheme "PrebidDemo" -destination 'platform=iOS Simulator,name=iPhone 8 Plus,OS=12.1' | xcpretty

if [ "${PIPESTATUS[0]}" -ne "0" ]; then
    echo "Error: xcodebuild failed"; exit 1;
fi
echo "End demo app build"

cd ../
echo $PWD
git checkout master
git pull origin master

echo "Do you want to create a tag (yes/no)?"
read uservar

if [ "$uservar" = "yes" ]
then
    echo "Enter tag name"
    read tagName
    if [ -z "$tagName" ]
    then
        echo "Tag not created"
    else
        git tag $tagName
        git push $tagName
        echo "build podspec"
        perl -pi -e 's/s.version.*/s.version      = "'$tagName'"/g' PrebidMobile.podspec
        pod lib lint PrebidMobile.podspec --verbose
        if [$? -eq 0]; then
            echo "podspec lint successfull"
            pod trunk push PrebidMobile.podspec --verbose
            if [$? -eq 0]; then
                curl -X POST --data-urlencode "payload={\"channel\": \"#pbm-sdk-devs\", \"username\": \"webhookbot\", \"text\": \"New version of PrebidMobile sdk for iOS has been uploaded to cocoapods.\", \"icon_emoji\": \":ghost:\"}" https://hooks.slack.com/services/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
            else
                echo "push to cocoapods failed"
            fi
        else
            echo "podspec lint failed"
        fi

    fi
else
    echo "Tagging and release exited"
fi
