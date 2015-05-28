A simple script that uses rsync to make a minimal image of the current os.

Usage: ./mini_image.sh <filename> <device - optional>
       ./mini_image.sh backup.img sda

The image can be made on the current device if %used is below ~48%
    Freesapce is check to see if there is enough room

Using the system during image creation should be keep between none and minimal

Although it is writen for pi folks, other then dependency retrival, it should work on any Linux system
