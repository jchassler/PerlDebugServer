PerlDebugServer
===============

This module provide a server for debugging multiples perl processes.

Lots of debugging modules a available for perl (graphical and non graphical), their are all directly attached to the debugged script.
This implies the following limitation : 
  - it is not easy to debug multiple processes (10 processes implies 10 debugging shell windows)
  - it is not easy to debug forking processes 
  - it is not easy to automate breakpoints. breakpoints should be set again at each script execution (and automation is not trivial)

This module aims at providing an debugging engine so that we can provide a debugger equivalent the jvm one where you can observe and halt each jvm thread as you want but working with perl processes instead of jvm threads. Every debugging processes connect to the debugging server providing runtime informations and receiving breakpoint list to set.

This module aims at providing a convenient base be to develop one or more GUI client to control this debug server.

Currently there are no GUI clients available.

A first version of the server is now available.

One can launch one server and debug as many processes as he wants :
- all debugging informations are centralized by the server
- all debugging commands are sent by the server when it receives a client request

For example, the tests script "01-debug-script.t" launch a debug server and 3 processes. All processes are being debugged at the same time (breakpoints are set for all processes).

Limitations :
Works only for linux systems (should be possible to make it works for windows)
No GUI client available today.
It doesn't manage for now forking processes.

