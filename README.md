SIRC_HW
=======

Implementation of SIRC, hardware end code for a Xilinx virtex 5 XUPV5 and virtex 6 ML605 devices inside folders. This project has separate works which are made to work with both actual hardware PUF and software PUF. PUF - Physically Unclonable Function.


Network configuration

Disable Realtek PCI (or Broadcom) network. Only one of them but not both. It worked for me with Realtek disabled
Check if LAN wire is connected to Broadcom
IPv4 settings for Broadcom ip : 192.168.137.1 Subnet mask : 255.255.255.0 Default gateway : . . . . DNS server : . . . . (both)
Go to advanced in IPv4 --> Add IP address ip : 192.168.1.10 subnet : 255.255.255.0
Make sure Microsoft Loopback Adapter is enabled (one of the 3 availble networks)
Go to IPv4 for Microsoft Loopback --> Obtain an IP address auto --> Use the following DNS server preferred : 10.128.92.32 alternate : 10.129.92.32
Program the board via Jtag before attempting to send software commmands on the FPGA reboot (U always missed this !)
NOTE : A few steps above may not be required but with this settings its working for me.

We may enable the other network once we do a software connection. It doesn't effect until the next board or network reboot or connections change. This is essential as we need to verify license to compile and generate new program files
