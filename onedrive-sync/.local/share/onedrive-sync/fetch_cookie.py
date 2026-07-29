#!/bin/python3

import sqlite3
import subprocess

# from pycookiecheat import BrowserType, get_cookies # only required for decrypting chromium cookies

# This script fetches the current rtFa and FedAuth auth cookies of MS sharepoint.com from the Firefox
# or Chromium cookies database (tested with MS Edge for linux) and updates the *last line* of
# davfs2.conf or rclone.conf files with those cookies. There must not be empty lines at the end of those files.
#
# NB! chromium and webdavfs2 options are disabled in this fork. just uncomment relevant lines if using either tool
#
# This essentially enables mounting all files of a OneDrive Business account as a local WebDAV share in Linux
# *without* any special permissions required by the tennant org.
# This script needs to be executed again when the cookies have expired, which is usually every few days.
# It may need to be run as root, depending on the locations of davfs2.conf and the chosen profile folder of firefox.

# adapt firefox_cookies or chromium_cooies variable below to match the browser's profile path
# adapt davfs2_conf and/or rclone_conf variables to the respective path of each file (both can be used simultaneously for testing)
# adapt the tennant variable to your sharepoint's tennant name
# the tennant name equals the prefix of the sharepoint url as shown after logging in
# (e.g. the xxx part in xxx-my.sharepoint.com)

# for davfs2 create a new /etc/fstab entry like the following line, replacing TENNANT, USER, DOMAIN and TLD (e.g. com, de, etc.):
# https://TENNANT-my.sharepoint.com/personal/USER_DOMAIN_TLD/Documents/ /mnt/onedrive davfs user,rw,noauto 0 0
#
# Davfs2 shows currently (Feb. 2025) a seg fault issue in combination with Nautilus and other file browsers, that can be avoided by
# using rclone's mount feature instead.
# An rclone.conf entry should look like this:
# [oneDrive]
# type = webdav
# url = https://TENNANT-my.sharepoint.com/personal/USER_DOMAIN_TLD/Documents
# vendor = other
# user = (email address)
# pass = XXXXX (generate with rclone obscure)
# headers = "Cookie","FedAuth=XXX;rtFa=XXX;"
#
# Notes:
#   TENNANT and DOMAIN are often the same, but sometimes not - as in larger company holding setups
#   USER is the part before the @ in your company email, with dots being replaced by underscores
#   DOMAIN and TLD are usally the parts after the @ in your company email
#   if you create a share link of any file in your sharepoint account (share as viewable by anyone),
#   the resulting URL shows the required TENNANT, USER, DOMAIN and TLD values
#
# more references here: https://github.com/johnbeard/onedrive_davfs_cookie_ext/blob/master/README.md (the AddOn itself didn't work for me)

# adapt the following three/four variables to your setup (see notes above):

# davfs2_conf = "/etc/davfs2/davfs2.conf" #(could be also in the local user folder, ~/.davfs2/davfs2.conf)
rclone_conf = "/home/lorenzo/.config/rclone/rclone.conf"

# chromium_cookies = "/home/lorenzo/.config/vivaldi/Default/Cookies" #define *either* chromium_cookies or firefox_cookies
firefox_cookies = "/home/lorenzo/.config/mozilla/firefox/0rcj4d3a.default/cookies.sqlite"  # replace user folder and XXX.default with your actual profile folder

tennant = "itisvolta"  # replace with the actual Microsoft tennant name of your company (see notes above)

yes = {"yes", "y", "ye"}

# opens firefox to generate new cookie
answer = input("Open sharepoint in Firefox to autheticate? (Y/n): ").strip().lower()

if answer in yes:
    try:
        # Launch Firefox and wait until it closes
        process = subprocess.Popen(
            [
                "firefox",
                "https://itisvolta-my.sharepoint.com/personal/lorenzo_baracco_volta-alessandria_it1/Documents",
            ]
        )
        print("Firefox opened. Waiting for it to close...")
        process.wait()
        print("Firefox closed. Continuing...")
    except FileNotFoundError:
        print("Firefox not found. Make sure it's installed and in PATH.")
else:
    print("Did not open firefox")
    exit()

# --- no need to adapt anything below this line

# for reference: fetching cookies from MS Edge for Linux on the command line:
# python3 -m pycookiecheat -b chromium -c ~/.config/microsoft-edge/Default/Cookies -vvv  https://sharepoint.com
# python3 -m pycookiecheat -b chromium -c ~/.config/microsoft-edge/Default/Cookies -vvv  https://TENNANT-my.sharepoint.com

if "firefox_cookies" in globals():
    print("Fetching cookies from Firefox database...")
    uri = "file:" + firefox_cookies + "?immutable=1"

    cookies = sqlite3.connect(
        uri, uri=True
    )  # , check_same_thread=False, isolation_level="IMMEDIATE")

    cursor = cookies.cursor()
    auth = cursor.execute(f"select value from main.moz_cookies \
                        where host = '.sharepoint.com' and name = 'rtFa' \
                        or host = '{tennant}-my.sharepoint.com' and name = 'FedAuth' ;")

    fetched = auth.fetchall()
    rtFa = fetched[0][0]
    FedAuth = fetched[1][0]

# elif 'chromium_cookies' in globals():
#     print("Fetching cookies from Chromium database...")
#     rtFa = get_cookies("https://sharepoint.com", browser=BrowserType.CHROMIUM, cookie_file=chromium_cookies)["rtFa"]
#     FedAuth = get_cookies(f"https://{tennant}-my.sharepoint.com", browser=BrowserType.CHROMIUM,cookie_file=chromium_cookies)["FedAuth"]

files = []
type = []

# if 'davfs2_conf' in globals():
#     files.append(davfs2_conf)
#     type.append("davfs2")

if "rclone_conf" in globals():
    files.append(rclone_conf)
    type.append("rclone")

for key, file in enumerate(files):
    with open(file, "r+") as f:
        lines = f.readlines()
        if type[key] == "davfs2":
            for i, line in enumerate(lines):
                if line.find("use_locks") != -1:
                    lines[i] = (
                        "use_locks 0\n"  # disable locks to avoid problems with the sharepoint webdav server
                    )
        last_line = lines[-1]
        print("The last line of", file, "is:")
        print(last_line)
        if type[key] == "davfs2":
            new_header = f"add_header	Cookie	rtFa={rtFa};FedAuth={FedAuth};"
            match = "add_header	Cookie"
        elif type[key] == "rclone":
            new_header = f'headers = "Cookie","FedAuth={FedAuth};rtFa={rtFa};"'
            match = 'headers = "Cookie",'
        if last_line.find(match) == -1:
            print(
                f"WARNING: config in {file} is not as expected (maybe a trailing empty line?):"
            )
            print("header definition not found in last line")
            print(
                "=> continue with pressing Enter or 'y', if you execute this script for the first time!"
            )
            print("Do you want to append a new header line? [Y/n]")
            input = input().lower()
            if input not in yes:
                print("OK, aborting...")
                exit()
            else:
                print("Appending new header line to dav2fs.conf:")
                lines.append(new_header)
        else:
            print("Great, found existing header on last line!")
            print("Replacing old cookie auth with new values:")
            lines[-1] = new_header
        print(lines[-1])
        f.seek(0)
        f.writelines(lines)
        f.truncate()
        f.close()

print("Done!")
