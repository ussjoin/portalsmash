PortalSmash
===========

Utility to connect to open WiFi and click through "captive portal"-type
agreements.

PortalSmash will scan, find open (or known, more on this later) WiFi, and
then try to connect to it, get an IP address, and get to the Web. If it
succeeds, it will keep checking the connection every few seconds, and restart
if it fails (allowing it to be used on mobile devices).

PortalSmash needs to be run as root, because otherwise DHClient and 
WPA_Supplicant don't do what it wants. (Sorry about that.)

PortalSmash derives from Malice Afterthought's Reticle project.

To use:

   sudo ./portalsmash.rb [-d devicename] [-n netconfig file]
       
Netfile format:
PortalSmash allows a network key file to be specified that includes, well, keys
for networks. The file must be in YAML, and formatted approximately as so:

    ---
    NetName:
        key: ohboyitsakey 
    HypotheticalWPAE:
        username: foo
        password: bar

This will allow the program to connect to WiFi for which you have been given
credentials (e.g., your home WiFi network). PortalSmash will connect to known
networks before unknown networks.


(C) 2012-2013, Malice Afterthought, Inc.

This software is provided 'as-is', without any express or implied
warranty, including the warranties of merchantability or fitness for a 
particular purpose.  In no event will the authors be held liable for any damages
arising from the use of this software. Use this software at your own risk;
unauthorized access to systems by an end-user is not the responsibility of
the author.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

(Some of the text for this license taken from the famous ZLib license,
available at http://www.gzip.org/zlib/zlib_license.html .)