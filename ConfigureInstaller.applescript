on run argv
    set mountPath to item 1 of argv
    set volumeFolder to POSIX file mountPath as alias
    set backgroundFile to POSIX file (mountPath & "/.background/Installer.png") as alias
    tell application "Finder"
        open volumeFolder
        set installerWindow to container window of volumeFolder
        set current view of installerWindow to icon view
        set toolbar visible of installerWindow to false
        set statusbar visible of installerWindow to false
        set bounds of installerWindow to {120, 120, 940, 728}
        set options to icon view options of installerWindow
        set arrangement of options to not arranged
        set icon size of options to 112
        set text size of options to 13
        set shows item info of options to false
        set shows icon preview of options to false
        set background picture of options to backgroundFile
        set position of item "BackCraft.app" of installerWindow to {205, 260}
        set position of item "Applications" of installerWindow to {615, 260}
        update volumeFolder without registering applications
        delay 2
        close installerWindow
        delay 2
        open volumeFolder
        delay 2
    end tell
end run
